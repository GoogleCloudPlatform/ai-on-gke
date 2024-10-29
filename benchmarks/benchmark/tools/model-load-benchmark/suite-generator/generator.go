package suitegenerator

import (
	"fmt"
	"reflect"
	"tool/config"
)

var RequestLimitMap = map[string]string{
	"CPURequest":              "CPULimit",
	"MemoryRequest":           "MemoryLimit",
	"EphemeralStorageRequest": "EphemeralStorageLimit",
}

type Suite struct {
	BaseCase config.Config
	Cases    []config.Config
}

// GenerateCases creates test cases
func GenerateCases(base config.Config) *Suite {
	suite := Suite{BaseCase: deepCopyConfig(base)}
	suite.Cases = generateSideCarAndVolumeCases(base)
	return &suite
}

func generateSideCarAndVolumeCases(base config.Config) []config.Config {
	sideCarCases := []config.Config{deepCopyConfig(base)}
	if base.SideCarResources != nil {
		sideCarCases = generateResourceCasesForStruct(base, "SideCarResources", reflect.ValueOf(base.SideCarResources))
	}
	fmt.Printf("Number of sidecarresource combinations generated %v \n", len(sideCarCases))

	var volumeCases []config.Config
	for _, sideCarCase := range sideCarCases {
		if sideCarCase.VolumeAttributes != nil {
			generatedVolumeCases := generateResourceCasesForStruct(sideCarCase, "VolumeAttributes", reflect.ValueOf(sideCarCase.VolumeAttributes))
			volumeCases = append(volumeCases, generatedVolumeCases...)
		} else {
			volumeCases = append(volumeCases, sideCarCase)
		}
	}
	fmt.Printf("Number of sidecarresource and volume case combinations generated %v\n", len(volumeCases))

	var finalCases []config.Config
	for _, volumeCase := range volumeCases {
		if volumeCase.VolumeAttributes != nil {
			generatedBoolCases := generateBoolCasesForStruct(volumeCase)
			finalCases = append(finalCases, generatedBoolCases...)
		} else {
			finalCases = append(finalCases, volumeCase)
		}
	}
	fmt.Printf("Number of all combinations generated %v \n", len(finalCases))

	if len(finalCases) == 0 {
		finalCases = append(finalCases, deepCopyConfig(base))
	}

	return finalCases
}

func generateBoolCasesForStruct(base config.Config) []config.Config {
	var cases []config.Config

	combinations := []struct {
		EnableParallelDownloads bool
		FileCacheForRangeRead   bool
	}{
		{true, true},
		{true, false},
		{false, true},
		{false, false},
	}

	for _, combo := range combinations {
		newCase := deepCopyConfig(base)

		if newCase.VolumeAttributes != nil {
			newCase.VolumeAttributes.MountOptions.FileCache.EnableParallelDownloads = combo.EnableParallelDownloads

			if !combo.EnableParallelDownloads {
				newCase.VolumeAttributes.MountOptions.FileCache.ParallelDownloadsPerFile.Base = 0
				newCase.VolumeAttributes.MountOptions.FileCache.MaxParallelDownloads.Base = 0
			}
		}

		if newCase.VolumeAttributes != nil {
			newCase.VolumeAttributes.FileCacheForRangeRead = combo.FileCacheForRangeRead
		}

		cases = append(cases, newCase)
	}

	return cases
}

func generateResourceCasesForStruct(base config.Config, structName string, structVal reflect.Value) []config.Config {
	var cases []config.Config

	for i := 0; i < structVal.Elem().NumField(); i++ {
		field := structVal.Elem().Field(i)
		fieldType := structVal.Elem().Type().Field(i)

		if field.Type() == reflect.TypeOf(config.Resource{}) {
			resource := field.Interface().(config.Resource)
			if resource.Step > 0 && resource.Max > resource.Base {
				// Check if the field is a request that has a limit
				limitFieldName, isRequest := RequestLimitMap[fieldType.Name]
				limitField := structVal.Elem().FieldByName(limitFieldName)
				limitExceeded := false
				var limitResource config.Resource
				var normalizedLimit int
				if limitField.IsValid() {
					limitResource = limitField.Interface().(config.Resource)
					var e error
					normalizedLimit, e = normalizeToBaseUnit(limitResource.Base, limitResource.Unit)
					if e != nil {
						fmt.Printf("Error normalizing limit: %v\n", e)
						continue
					}
				}
				// request should be less than limit
				if isRequest {
					if limitField.IsValid() {
						// Normalize both resources to the same unit for comparison
						normalizedRequest, err := normalizeToBaseUnit(resource.Base, resource.Unit)
						if err != nil {
							fmt.Printf("Error normalizing request: %v\n", err)
							continue
						}
						// Compare the normalized values
						if normalizedRequest > normalizedLimit {
							limitExceeded = true
						}
					}
				}

				// Create cases if limits aren't exceeded
				if !limitExceeded {
					for val := resource.Base; val <= resource.Max; val += resource.Step {
						if val > resource.Max {
							break
						}

						newCase := deepCopyConfig(base)
						updatedResource := config.Resource{Base: val, Unit: resource.Unit, Step: resource.Step, Max: resource.Max}
						// request should be less than limit
						if isRequest {
							if limitField.IsValid() {
								// Normalize both resources to the same unit for comparison
								normalizedRequest, err := normalizeToBaseUnit(updatedResource.Base, updatedResource.Unit)
								if err != nil {
									fmt.Printf("Error normalizing request: %v\n", err)
									continue
								}

								// Compare the normalized values
								if normalizedRequest > normalizedLimit {
									continue
								}
							}
						}

						if structName == "SideCarResources" {
							newCase.SideCarResources = setNestedResourceField(newCase.SideCarResources, fieldType.Name, updatedResource).(*config.SideCarResources)
						} else if structName == "VolumeAttributes" {
							newCase.VolumeAttributes = setNestedResourceField(newCase.VolumeAttributes, fieldType.Name, updatedResource).(*config.VolumeAttributes)
						}
						cases = append(cases, newCase)
					}
				}
			}
		}
	}
	return cases
}

func deepCopyConfig(base config.Config) config.Config {
	copy := base
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
	return copy
}

func normalizeToBaseUnit(value int, unit string) (int, error) {
	switch unit {
	case "Mi":
		return value * 1_024, nil
	case "Gi":
		return value * 1_024 * 1_024, nil
	case "Ti":
		return value * 1_024 * 1_024 * 1_024, nil
	case "":
		return value * 1_000, nil // Convert cores to milli-cores
	case "m":
		return value, nil
	default:
		return value, nil
	}
}

func setNestedResourceField(nested interface{}, fieldName string, value config.Resource) interface{} {
	v := reflect.ValueOf(nested).Elem()
	field := v.FieldByName(fieldName)
	if field.IsValid() && field.CanSet() {
		field.Set(reflect.ValueOf(value))
	}
	return v.Addr().Interface()
}
