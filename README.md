# Project

This repo contains a subset of samples over **Azure Sentinel** for covering the following topics:
- DevOps use cases like Artifacts Deployment or Connector enablement
- MITRE use cases as technical reference for different Azure Services

## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

# Sentinel Landscape Framework

A collection of samples to cover different aspecto on the lifecycle for a Sentinel deployment is available on this repository, including:

### **Connector Mananagement Framework**

Using this sample you can enable, disable and check status of the Sentinel Connectors based on REST API
- Connectors, which allows to enable, disable and check status for the following datasources:
- Azure Active Directory
- Azure Active Directory Identity Protection
- Azure Defender for Cloud
- Azure Activity
- Office 365 Logs
- Microsoft 365 Defender
- MCAS
- TAXII Server
- Threat Intelligence Platform (Graph API)

### **Sentinel Artifacts**

Using these samples you can add, update and remove different artifacts on Azure Sentinel like:

- **Analytic Rules Framework**, which allows to export and import Analytic Rules over a specific Sentinel instance
- **Hunting Rules Framework**, which allows to export and import Hunting Rules over a specific Sentinel instance
- **Live Stream Rules Framework**, which allows to export and import Live Stream Rules over a specific Sentinel instance
- **Automation Rules Framework**, which allows to export and import Automation Rules over a specific Sentinel instance
- **Workbooks Framework**, which allows to export and import Workbooks over a specific Sentinel instance
- **Watchlists Framework**, which allows to export and import Watchlists over a specific Sentinel instance
- **Playbooks Framework**, which allows to deploy and export Playbooks for being used in a specific Sentinel instance
- **Runbooks Framework**, which allows to deploy and export Runbooks on an Automation Account

### **MITRE Use Cases**

Using these samples, you can see a code organization considering different Azure Sentinel artifacts classified by different Azure Services as target. 