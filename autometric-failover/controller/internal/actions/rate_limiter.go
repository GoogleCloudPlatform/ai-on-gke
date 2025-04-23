package actions

import (
	"sync"
	"time"

	v1 "github.com/GoogleCloudPlatform/ai-on-gke/autometric-failover/controller/api/v1"
)

// RateLimiter defines the interface for rate limiting actions
type RateLimiter interface {
	IsRateLimited(actionType v1.ActionType) bool
	UpdateRateLimit(actionType v1.ActionType)
}

// NoRateLimiter implements RateLimiter with no-op behavior
type NoRateLimiter struct{}

func (n *NoRateLimiter) IsRateLimited(actionType v1.ActionType) bool {
	return false
}

func (n *NoRateLimiter) UpdateRateLimit(actionType v1.ActionType) {
	// No-op
}

// InMemoryRateLimiter implements RateLimiter with a basic time-based approach
type InMemoryRateLimiter struct {
	rateLimits    map[v1.ActionType]time.Time
	rateLimitDurs map[v1.ActionType]time.Duration
	mu            sync.RWMutex
}

// NewInMemoryRateLimiter creates a new InMemoryRateLimiter with the given durations
func NewInMemoryRateLimiter(rateLimitDurs map[v1.ActionType]time.Duration) *InMemoryRateLimiter {
	if rateLimitDurs == nil {
		rateLimitDurs = make(map[v1.ActionType]time.Duration)
	}

	// Set default duration for each action type if not specified
	for _, actionType := range []v1.ActionType{
		v1.ActionTypeCordonNodepool,
		v1.ActionTypeCordonNodepoolAndRestartJobSet,
		v1.ActionTypeCordonAndRepairNodepool,
		v1.ActionTypeRepairNodepool,
	} {
		if _, exists := rateLimitDurs[actionType]; !exists {
			rateLimitDurs[actionType] = 1 * time.Hour
		}
	}

	return &InMemoryRateLimiter{
		rateLimits:    make(map[v1.ActionType]time.Time),
		rateLimitDurs: rateLimitDurs,
	}
}

func (r *InMemoryRateLimiter) IsRateLimited(actionType v1.ActionType) bool {
	r.mu.RLock()
	defer r.mu.RUnlock()

	lastExec, exists := r.rateLimits[actionType]
	if !exists {
		return false
	}

	minInterval := r.rateLimitDurs[actionType]
	return time.Since(lastExec) < minInterval
}

func (r *InMemoryRateLimiter) UpdateRateLimit(actionType v1.ActionType) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.rateLimits[actionType] = time.Now()
}
