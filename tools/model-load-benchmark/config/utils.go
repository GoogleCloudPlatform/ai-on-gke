package config

import (
	"strconv"
	"strings"
)

// Helper function to parse values with units
func parseValueUnit(value string) (int, string) {
	numStr := strings.TrimRightFunc(value, func(r rune) bool {
		return r < '0' || r > '9'
	})
	unit := strings.TrimPrefix(value, numStr)
	num, _ := strconv.Atoi(numStr)
	return num, unit
}
