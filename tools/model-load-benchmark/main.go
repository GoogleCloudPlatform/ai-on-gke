package main

import (
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"tool/runner"

	"github.com/sirupsen/logrus"
	"github.com/spf13/cobra"
	"gopkg.in/ini.v1"
)

var (
	rootCmd = &cobra.Command{
		Use:   "benchmarker",
		Short: "A benchmarking tool",
		Long:  `A tool for running benchmarks.`,
	}
	configCmd = &cobra.Command{
		Use:   "config",
		Short: "Manage configuration",
		Long:  `Commands for managing the configuration.`,
	}
	configFile string
	setCmd     = &cobra.Command{
		Use:   "set",
		Short: "Set the configuration file",
		Long:  `Set the configuration file for the application.`,
		Run:   setConfig,
	}
	runCmd = &cobra.Command{
		Use:   "run",
		Short: "Run the benchmarks",
		Long:  `Run the benchmarks using the configured settings.`,
		Run:   run}
)

func initLogger() *logrus.Logger {
	logger := logrus.New()
	logger.SetOutput(os.Stderr)
	logger.SetLevel(logrus.InfoLevel)
	logger.SetFormatter(&logrus.TextFormatter{
		FullTimestamp:   true,
		TimestampFormat: "2024-09-24T15:04:05.000Z07:00",
		CallerPrettyfier: func(f *runtime.Frame) (string, string) {
			return "", fmt.Sprintf("%s:%d", filepath.Base(f.File), f.Line)
		},
		DisableLevelTruncation: true, // Prevent level truncation
	})
	logger.SetReportCaller(true)
	return logger
}

var logger = initLogger()

func initCobra() {
	setCmd.Flags().StringVarP(&configFile, "file", "f", "", "Path to the configuration file")
	_ = setCmd.MarkFlagRequired("file")
	configCmd.AddCommand(setCmd)
	rootCmd.AddCommand(configCmd)
	rootCmd.AddCommand(runCmd)
	if err := rootCmd.Execute(); err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
}

// ... (other variables and functions)

func setConfig(cmd *cobra.Command, args []string) {
	// Get the config file path from the flag
	configFile, _ := cmd.Flags().GetString("file")

	// Create the .config directory if it doesn't exist

	// Load or create the .ini file
	configFilePath := "benchmarker.ini"
	cfg, err := ini.Load(configFilePath)
	if err != nil {
		// Create a new .ini file if it doesn't exist
		cfg = ini.Empty()
		cfg.NewSection("default") // Create a default section
	}

	// Set the config_path value
	cfg.Section("default").Key("MODEL_LOAD_BENCHMARK_CONFIG").SetValue(configFile)

	// Save the .ini file
	err = cfg.SaveTo(configFilePath)
	if err != nil {
		logger.Errorf("Failed to save config file: %v", err)
		return
	}

	logger.Infof("Config file set to: %s", configFile)
}

func run(cmd *cobra.Command, args []string) {
	configFilePath := "benchmarker.ini"

	// Load the .ini file
	cfg, err := ini.Load(configFilePath)
	if err != nil {
		logger.Error("Config file not found. Use 'config set' command first.")
		return
	}

	// Get the config_path value
	configFile := cfg.Section("default").Key("MODEL_LOAD_BENCHMARK_CONFIG").String()
	if configFile == "" {
		logger.Error("Config file path not found in config file.")
		return
	}

	runner, err := runner.InitRunner(configFile)
	if err != nil {
		logger.Errorf("Failed to initialize runner: %v", err)
		return
	}
	runner.Run()
}

func main() {
	initCobra()
}
