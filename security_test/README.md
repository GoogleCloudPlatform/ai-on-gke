# Shipshape Validation Service - User Guide

## Overview
The Shipshape Validation Service validates Kubernetes YAML configurations against predefined security policies. This ensures compliance and enhances the security of Kubernetes deployments.

If your e2e test fails due to a policy violation detected by Shipshape, you have two options:
1. **Fix the Code**: Resolve the violation by modifying the code to comply with the specified policy. You may consult the GKE Hardening team for guidance.
2. **Add to Allowlist**: If the violation is a known exception, you can add it to the allowlist to prevent it from blocking your build.

---

## Example Violation

**Violation:**
```json
{
    "details": {
        "@type": "type.googleapis.com/google.internal.kubernetes.security.validation.v1.ContainerDetails",
        "containerName": "kuberay-tpu-webhook"
    },
    "message": "container \"kuberay-tpu-webhook\" in Deployment \"kuberay-tpu-webhook\" does not set readOnlyRootFilesystem: true in its securityContext. This setting is encouraged because it can prevent attackers from writing malicious binaries into runnable locations in the container filesystem.",
    "policyName": "readonlyrootfs",
    "resourceKey": {
        "group": "apps",
        "kind": "Deployment",
        "name": "kuberay-tpu-webhook",
        "namespace": "ray-system",
        "version": "v1"
    }
}
```
## Steps to Address the Violation

### Option 1: Fix the Code
1. Identify the root cause of the violation from the validation output.
2. Update the Kubernetes YAML or Helm chart to comply with the security policy. For example, in the above violation:
    - Add the following snippet under `securityContext` for the `kuberay-tpu-webhook` yaml:
      ```yaml
      securityContext:
        readOnlyRootFilesystem: true
      ```
3. Run the e2e test again to confirm the issue is resolved.
4. For further assistance, reach out to the **GKE Hardening team**.

---

### Option 2: Add to Allowlist
If the violation is a known exception, you can add it to the allowlist:

1. **Locate the Allowlist Directory**:  
   Navigate to the directory:
   ```bash
   security_test/allowlist/category
   ```
2. Create a JSON File

3. Use the policy name from the violation (`readonlyrootfs`) as the filename.
    - Example: `readonlyrootfs.json`

4. **Add the Allowlist Entry**:  
   Populate the JSON file with the relevant details from the violation. For the above example, please only change the message part:

   ```json
    [
        {
            "details": {
                "@type": "type.googleapis.com/google.internal.kubernetes.security.validation.v1.ContainerDetails",
                "containerName": "kuberay-tpu-webhook"
            },
            "policyName": "readonlyrootfs",
            "resource": {
                "group": "apps",
                "kind": "Deployment",
                "name": "kuberay-tpu-webhook",
                "namespace": "ray-system",
                "version": "v1"
            },
            "message": "Known exception for the kuberay-tpu-webhook component."
        }
    ]
   ```

### Additional Notes

- Always prioritize fixing code violations whenever feasible.
- Use the allowlist option sparingly and only for documented exceptions.
- For further queries or support, contact the **GKE Hardening team**.