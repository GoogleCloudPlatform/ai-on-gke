package main

import "testing"

func Test_unquote(t *testing.T) {
	tests := []struct {
		name string
		args string
		want string
	}{
		{
			name: "simple double quotes",
			args: `"hello"`,
			want: "hello",
		},
		{
			name: "simple single quotes",
			args: `"hello"`,
			want: "hello",
		},
		{
			name: "simple no quotes",
			args: `hello`,
			want: "hello",
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := unquote(tt.args); got != tt.want {
				t.Errorf("unquote() = %v, want %v", got, tt.want)
			}
		})
	}
}
