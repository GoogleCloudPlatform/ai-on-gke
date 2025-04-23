package server

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"time"

	v1 "github.com/GoogleCloudPlatform/ai-on-gke/autometric-failover/controller/api/v1"
	"github.com/GoogleCloudPlatform/ai-on-gke/autometric-failover/controller/internal/actions"
	"sigs.k8s.io/controller-runtime/pkg/log"
)

type Server struct {
	mux         *http.ServeMux
	actionTaker actions.ActionTakerInterface
}

func New(actionTaker actions.ActionTakerInterface) *Server {
	s := &Server{
		mux:         http.NewServeMux(),
		actionTaker: actionTaker,
	}
	s.mux.HandleFunc("/actions", s.handleActions)
	return s
}

func (s *Server) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	s.mux.ServeHTTP(w, r)
}

func (s *Server) handleActions(w http.ResponseWriter, r *http.Request) {
	start := time.Now()
	logID := fmt.Sprintf("request-%s-%d", r.RemoteAddr, start.UnixNano())

	log := log.FromContext(r.Context()).WithValues(
		"id", logID,
		"method", r.Method,
		"remoteAddr", r.RemoteAddr,
		"userAgent", r.UserAgent(),
	)

	log.Info("Received action request")

	defer func() {
		log.Info("Completed action request", "duration", time.Since(start))
	}()

	if r.Method != http.MethodPost {
		log.Error(nil, "Method not allowed")
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req v1.ActionRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		log.Error(err, "Failed to decode action request")
		sendErrorResponse(w, "", http.StatusBadRequest, err)
		return
	}
	defer r.Body.Close()

	if err := req.DefaultAndValidate(); err != nil {
		log.Error(err, "Invalid action request")
		sendErrorResponse(w, req.ID, http.StatusBadRequest, err)
		return
	}

	log = log.WithValues(
		"requestId", req.ID,
		"type", req.Type,
		"jobsetName", req.JobSetName,
		"jobsetNamespace", req.Namespace,
		"nodePool", req.NodePool,
	)

	log.V(1).Info("Processing action request")

	if err := s.actionTaker.TakeAction(r.Context(), req); err != nil {
		log.Error(err, "Failed to take action")

		// Check if the error is a RateLimitError
		if errors.Is(err, actions.RateLimitError) {
			sendErrorResponse(w, req.ID, http.StatusTooManyRequests, err)
			return
		}

		sendErrorResponse(w, req.ID, http.StatusInternalServerError, err)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(v1.ActionResponse{
		ID: req.ID,
	}); err != nil {
		log.Error(err, "Failed to encode response")
	}
}

func sendErrorResponse(w http.ResponseWriter, id string, code int, err error) {
	w.WriteHeader(code)
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(v1.ActionResponse{
		ID:    id,
		Error: err.Error(),
	})
}
