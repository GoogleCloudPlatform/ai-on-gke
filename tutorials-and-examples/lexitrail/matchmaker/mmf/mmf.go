// Copyright 2024 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package main

import (
	"errors"
	"fmt"
	"log"
	"net"
	"time"

	"google.golang.org/grpc/credentials/insecure"
	"open-match.dev/open-match/pkg/matchfunction"

	"google.golang.org/grpc"
	"open-match.dev/open-match/pkg/pb"
)

const (
	matchName      = "first-match-mmf"
	mmlogicAddress = "open-match-query.open-match.svc.cluster.local:50503"
)

func main() {
	log.Println("Initializing")

	conn, err := grpc.Dial(mmlogicAddress, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		log.Fatal(err.Error())
	}
	defer conn.Close()

	mmf := matchFunctionService{
		queryServiceClient: pb.NewQueryServiceClient(conn),
	}

	server := grpc.NewServer()
	pb.RegisterMatchFunctionServer(server, &mmf)

	ln, err := net.Listen("tcp", ":50502")
	if err != nil {
		log.Fatal(err.Error())
	}

	log.Println("Serving started")
	err = server.Serve(ln)
	log.Fatalf("Error servering grpc: %s", err.Error())
}

type matchFunctionService struct {
	queryServiceClient pb.QueryServiceClient
}

func (mmf *matchFunctionService) Run(req *pb.RunRequest, stream pb.MatchFunction_RunServer) error {
	log.Printf("Running mmf")

	poolTickets, err := matchfunction.QueryPools(stream.Context(), mmf.queryServiceClient, req.GetProfile().GetPools())
	if err != nil {
		return err
	}

	// Make match proposal
	proposals, err := makeMatches(req.Profile, poolTickets)
	if err != nil {
		return err
	}

	matchesFound := 0
	for _, proposal := range proposals {
		err = stream.Send(&pb.RunResponse{Proposal: proposal})
		if err != nil {
			return err
		}
		matchesFound++
	}
	log.Printf("MMF ran creating %d matches", matchesFound)

	return nil
}

func makeMatches(profile *pb.MatchProfile, poolTickets map[string][]*pb.Ticket) ([]*pb.Match, error) {
	var matches []*pb.Match

	tickets, ok := poolTickets["everyone"]
	if !ok {
		return matches, errors.New("expected pool named everyone")
	}

	t := time.Now().Format("2006-01-02T15:04:05.00")

	for i := 0; i < len(tickets); i++ {
		proposal := &pb.Match{
			MatchId:       fmt.Sprintf("profile-%s-time-%s-num-%d", profile.Name, t, i),
			MatchProfile:  profile.Name,
			MatchFunction: matchName,
			Tickets: []*pb.Ticket{
				tickets[i],
			},
		}
		matches = append(matches, proposal)
	}
	return matches, nil
}
