package actions

import (
	"testing"
	"time"

	v1 "github.com/GoogleCloudPlatform/ai-on-gke/autometric-failover/controller/api/v1"
)

func TestInMemoryRateLimiter(t *testing.T) {
	tests := []struct {
		name                         string
		rateLimitDurs                map[v1.ActionType]time.Duration
		actionType                   v1.ActionType
		waitAndRetry                 time.Duration
		shouldBeRateLimitedAfterWait bool
	}{
		{
			name: "default rate limit duration",
			rateLimitDurs: map[v1.ActionType]time.Duration{
				v1.ActionTypeCordonNodepool: 1 * time.Hour,
			},
			actionType: v1.ActionTypeCordonNodepool,
		},
		{
			name: "custom rate limit duration short wait",
			rateLimitDurs: map[v1.ActionType]time.Duration{
				v1.ActionTypeCordonNodepool: 100 * time.Millisecond,
			},
			actionType:                   v1.ActionTypeCordonNodepool,
			waitAndRetry:                 10 * time.Millisecond,
			shouldBeRateLimitedAfterWait: true,
		},
		{
			name: "custom rate limit duration longer wait",
			rateLimitDurs: map[v1.ActionType]time.Duration{
				v1.ActionTypeCordonNodepool: 100 * time.Millisecond,
			},
			actionType:                   v1.ActionTypeCordonNodepool,
			waitAndRetry:                 101 * time.Millisecond,
			shouldBeRateLimitedAfterWait: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			limiter := NewInMemoryRateLimiter(tt.rateLimitDurs)

			// First check should not be rate limited
			if limiter.IsRateLimited(tt.actionType) {
				t.Errorf("IsRateLimited() = true, want false for first check")
			}

			// Update the rate limit
			limiter.UpdateRateLimit(tt.actionType)

			// Second check should be rate limited
			if !limiter.IsRateLimited(tt.actionType) {
				t.Errorf("IsRateLimited() = false, want true after UpdateRateLimit")
			}

			if tt.waitAndRetry > 0 {
				// Wait for the rate limit to expire
				time.Sleep(tt.waitAndRetry)

				// Third check should not be rate limited
				if isLimited := limiter.IsRateLimited(tt.actionType); isLimited != tt.shouldBeRateLimitedAfterWait {
					t.Errorf("IsRateLimited() = %v, want %v after rate limit expiration", isLimited, tt.shouldBeRateLimitedAfterWait)
				}
			}
		})
	}
}
