### Folder-per-feature 

Folder-per-feature an architecture that aims to compartmentalize game features. Each system is implemented under a folder titled after the system. 
Systems are implemented using the service/controller pattern, a pattern that creates server-sided APIs and client-sided APIs. Shared APIs can exist within this architecture.
Each feature is initialized by a **single** `Script` or `LocalScript`, depending on which end of the network the feature implementation puts focus on. These scripts are not always
**necessary**, as their primary purpose is describe the feature's explicit involvement in the codebase, should the feature be not solely used elsewhere.

## Server-sided implementation

Server-sided features are **always** implemented in `ServerScriptService`. These features will produce a **service** `ModuleScript`, an API that exposes the feature's functionality to the rest of the codebase.
The feature can be initialized by a `Script` named after the feature:

![image](https://github.com/user-attachments/assets/4f21bee4-e452-46eb-845b-b2177efac2f8)
