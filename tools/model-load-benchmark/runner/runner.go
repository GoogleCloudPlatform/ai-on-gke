package runner

import (
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strconv"
	"time"
	"tool/config"
	"tool/deployment"
	"tool/k8sclient"
	suitegenerator "tool/suite-generator"

	"github.com/sirupsen/logrus"
	"gopkg.in/yaml.v2"
	v1 "k8s.io/api/core/v1"
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

type Runner struct {
	k8sclient  *k8sclient.Client
	logger     *logrus.Logger
	baseConfig *config.Config
	suite      *suitegenerator.Suite
	resultsDir string
}
type CaseResult struct {
	ElapsedTime time.Duration `yaml:"elapsedTime"`
	Config      config.Config `yaml:"config"`
	Spec        v1.Pod        `yaml:"spec"`
	caseNo      string
}

func InitRunner(configFile string) (*Runner, error) {
	logger := initLogger()
	client, err := k8sclient.InitClient()
	if err != nil {
		return nil, fmt.Errorf("failed to initialize k8s client %v", err)
	}
	baseConfig, err := config.LoadConfig(configFile)
	if err != nil {
		return nil, fmt.Errorf("failed to initialize test config from file %q because %q", configFile, err)
	}
	baseConfigCopy := deepCopyConfig(baseConfig)
	suite := suitegenerator.GenerateCases(*baseConfigCopy)
	logger.Infof("Number of cases generated %v", len(suite.Cases))

	return &Runner{
		k8sclient:  client,
		logger:     logger,
		baseConfig: baseConfig,
		suite:      suite,
	}, nil
}
func deepCopyConfig(base *config.Config) *config.Config {
	copy := *base
	if base.SideCarResources != nil {
		sideCarCopy := *base.SideCarResources
		copy.SideCarResources = &sideCarCopy
	}
	if base.VolumeAttributes != nil {
		volumeCopy := *base.VolumeAttributes
		copy.VolumeAttributes = &volumeCopy
		if base.VolumeAttributes.MountOptions.FileCache != (config.FileCache{}) {
			fileCacheCopy := base.VolumeAttributes.MountOptions.FileCache
			copy.VolumeAttributes.MountOptions.FileCache = fileCacheCopy
		}
	}
	return &copy
}

func createResultsDirectory() (string, error) {
	currentDir, err := os.Getwd()
	if err != nil {
		return "", fmt.Errorf("failed to get current directory: %v", err)
	}
	resultsDir := filepath.Join(currentDir, "results")
	err = os.RemoveAll(resultsDir)
	if err != nil {
		return "", fmt.Errorf("failed to remove existing results directory: %v", err)
	}
	err = os.Mkdir(resultsDir, 0755)
	if err != nil {
		return "", fmt.Errorf("failed to create results directory: %v", err)
	}

	fmt.Println("Results directory created:", resultsDir)
	return resultsDir, nil
}

func (r *Runner) Run() {
	dir, err := createResultsDirectory()
	if err != nil {
		r.logger.Errorf("Failed to create results directory %v", err)
		return
	}
	r.resultsDir = dir
	r.logger.Infof("Number of cases generated %v", len(r.suite.Cases))
	nodes, err := r.k8sclient.GetNodes()
	if err != nil {
		r.logger.Errorf("Failed to get nodes from cluster")
		return
	}
	r.logger.Infof("Cluster has %v nodes", len(nodes.Items))
	r.DeployAndMonitorCases()
}

func (r *Runner) logFailedPodSpecCreation(c config.Config, e error) {
	cStr, err := c.PrettyPrint()
	if err != nil {
		r.logger.Errorf("Failed to marshal config %v", c)
	}
	r.logger.Errorf("Failed to generate pod spec for config %v error: %v", cStr, e)
}

func (r *Runner) DeployAndMonitorCases() error {
	for caseNo, c := range r.suite.Cases {
		r.logger.Infof("Starting Case no %v ", caseNo)
		d, err := deployment.NewDeployment(&c)
		if err != nil {
			r.logFailedPodSpecCreation(c, err)
			continue
		}

		duration, err := r.k8sclient.DeployAndMonitorPod(d.Pod)
		if err != nil {
			r.logger.Errorf("Pod case no:%v failed to be ready, %v", caseNo, err)
		}
		r.logger.Infof("Case no %v finished successfully in time %v", caseNo, duration)
		caseResult := CaseResult{
			ElapsedTime: duration,
			Config:      c,
			Spec:        *d.Pod,
			caseNo:      strconv.Itoa(caseNo),
		}
		r.saveCaseResultToYAML(caseResult)
	}
	return nil
}

func (r *Runner) saveCaseResultToYAML(result CaseResult) error {
	filename := fmt.Sprintf("%s/case_%s.yaml", r.resultsDir, result.caseNo)
	// Marshal the result to YAML
	yamlData, err := yaml.Marshal(result)
	if err != nil {
		return fmt.Errorf("failed to marshal CaseResult to YAML: %v", err)
	}
	yamlData = append(yamlData, '\n')
	// Write the YAML data to the file
	err = os.WriteFile(filename, yamlData, 0644)
	if err != nil {
		return fmt.Errorf("failed to write YAML file: %v", err)
	}

	return nil
}
