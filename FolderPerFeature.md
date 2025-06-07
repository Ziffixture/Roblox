# Contents
- [Introduction](#introduction)
- [Server-sided implementation](#server-sided-implementation)
- [Client-sided implementation](#client-sided-implementation)
- [Shared implementation](#shared-implementation)
- [Scripting convention](#scripting-convention)

<section id="introduction"><h1 style="border: none">Introduction</h1></section>

Folder-per-feature an architecture that aims to compartmentalize game features. Each system is implemented under a folder titled after the system. 
Systems are implemented using the service/controller pattern, a pattern that creates server-sided APIs and client-sided APIs. Shared APIs can exist within this architecture.
Each feature is initialized by a **single** `Script` or `LocalScript`, depending on which end of the network the feature implementation puts focus on. These scripts are not always
**necessary**, as their primary purpose is describe the feature's explicit involvement in the codebase, should the feature be not solely used elsewhere.

<section id="server-sided-implementation"><h2 style="border: none">Server-sided implementation</h2></section>

Server-sided features are **always** implemented in `ServerScriptService`. These features will produce a **service** `ModuleScript`, an API that exposes the feature's functionality to the rest of the codebase.
The feature can be initialized by a `Script` named after the feature:

![image](https://github.com/user-attachments/assets/4f21bee4-e452-46eb-845b-b2177efac2f8)

Configuration constants are abstracted from the code, and converted into a instance values parented under a `Configuration` instance:

![image](https://github.com/user-attachments/assets/d46b67a3-f7b9-4eb5-8529-bb558a9b31fb)

Type definitions are expected of this architecture, and abstracted to a `ModuleScript` named "Types":

![image](https://github.com/user-attachments/assets/fe1c44f5-7167-4e60-acaf-79e1987caa3c)

#### This is the basic structure of a feature.

<section id="slient-sided-implementation"><h2 style="border: none">Client-sided implementation</h2></section>

Client-sided features are **always** implemented in `ReplicatedStorage`. These features will provide a **controller** `ModuleScript`, an API that exposes the feature's functionality to the rest of the codebase.
The feature can be initialized by a `LocalScript` named after the feature. Types and configuration constants continue to be abstracted:

![image](https://github.com/user-attachments/assets/7df4d631-6d65-4388-98db-9d5dae5f92c0)

*(The `LocalScript` is a `Script`-turned-local via the [RunContext](https://create.roblox.com/docs/reference/engine/classes/Script#RunContext) property)*

<section id="shared-implementation"><h2 style="border: none">Shared implementation</h2></section>

Shared implementations are joined together with client-sided implementations due to their presence in `ReplicatedStorage`. A **shared** `ModuleScript` will be introduced:

![image](https://github.com/user-attachments/assets/5290683e-5925-4a22-86d8-5f471b429611)

<section id="scripting-convention"><h1 style="border: none">Scripting convention</h1></section>

All scripts begin with the following header, filled with my information for demonstration:
```lua
--[[
Author     Ziffixture (74087102)
Date       06/07/2025 (MM/DD/YYYY)
Version    1.0.0
]]



--!strict
```
The flow of a script largely follows this outline. Minor adjustments can be made to improve readability:

#### Section 1
1. Imports
- Roblox services
- Tooling/Features/other
2. Constants
3. Variables

#### Section 2
4. Helper functions
5. Functions

#### Section 3
7. Initialization
8. Type definitions
9. Exports

### Capitalization

Top-level imports will be capitalized using the PascalCase convention. Constants will be capitalized with the UPPER_SNAKE_CASE convention. Variables and the rest will be capitalized with the camelCase convention.
**All function signatures** must be typed. This means parameters and return values.

### Spacing

Three spaces are used to separate sections. Two spaces are used to separate subsections, and one space is used to separate unrelated variables from one another. Each subsection is aligned.

### Other

**Never-nesting** is enforced. For more information: https://www.youtube.com/watch?v=CFRhGnuXG-4

### Examples:

https://github.com/Ziffixture/Roblox/blob/main/MonetizationService.lua
