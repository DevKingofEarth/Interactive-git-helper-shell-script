# Interactive-git-helper-shell-script

> [!CAUTION]
> Although this code has been reviewed, it has been tailored with AI LLM assistance and some features still require testing, so it is still under development. The code has to be refactored further.
> **Please review the code thoroughly before use.** You can refer to the other documentation files if necessary.

The README.md would be gradually edited and updated.

Documentations you can use;

- Code Documentation : for debugging or easy understanding of script
- User Manual : to understand and ease of use for Interactions with the script.
- Also refer platform.conf for your setup.
- View below diagrams for easy visualization, but there might be mistakes, which will also be resolved gradually.

## Navigation flow diagram

```mermaid
flowchart TD
    Start[Start: repo-crafter.sh] --> Args{Command Line Args?}
    Args -- "--dry-run / -n" --> Dry[DRY-RUN Mode\nPreview Only]
    Args -- "--test / -t" --> Test[Run Tests & Exit]
    Args -- "--help / -h" --> Help[Show Help & Exit]
    Args -- "none" --> MainMenu
    
    Dry --> MainMenu
    
    subgraph MainMenu [Main Menu Loop]
        direction TB
        M1[🆕 Create New Project] --> M1_Sub
        M2[🔗 Convert Local → Remote]
        M3[🔓 Convert Remote → Local]
        M4[🗑️ Manage/Delete Project]
        M5[📋 List Remote Repositories]
        M6[⚙️ Configure .gitignore]
        M7[🧪 Test Configuration]
        M8[ℹ️ About this script]
        M9[🚪 Exit]
    end

    M1_Sub --> C1[Create Local + Remote]
    M1_Sub --> C2[Clone Existing Remote]
    M1_Sub --> C3[Create Local-Only]

```

## Functional/Processes Flow diagram

```mermaid
flowchart TD
    subgraph "Entry & Initialization"
        A["main()"] --> B["parse_args()\nDRY_RUN TEST HELP"]
        B --> C["check tools\ngit curl jq ssh"]
        C --> D["load_platform_config\nParse platforms.conf"]
        D --> E["Populate PLATFORM_* arrays"]
        E --> F["Build AVAILABLE_PLATFORMS"]
        F --> G["is_safe_directory"]
        G --> H["Offer test run"]
        H --> I["main_menu loop"]
    end

    subgraph "Core Workflow"
        direction TB
        I --> J1["1 Create New Project"]
        I --> J2["2 Convert Local to Remote"]
        I --> J3["3 Convert Remote to Local"]
        I --> J4["4 Manage Delete"]
        J1 --> W1["create_new_project_workflow"]
        J2 --> W2["convert_local_to_remote"]
        J3 --> W3["convert_remote_to_local"]
        J4 --> W4["manage_project_workflow"]
    end

    subgraph "Workflow 1: Create Project"
        W1 --> W1a{"How to start"}
        W1a -- "Local+Remote" --> W1b["_create_with_new_remote"]
        W1a -- "Clone Remote" --> W1c["_clone_existing_remote"]
        W1a -- "Local-Only" --> W1d["_create_local_only"]
        W1b --> W1e{DRY_RUN}
        W1e -- Yes --> W1y["preview_and_abort_if_dry\nEXIT SCRIPT"]
        W1e -- No --> W1g["platform_api_call POST"]
        W1g --> W1h{HTTP Success}
        W1h -- No --> W1k["_cleanup_failed_creation"]
        W1h -- Yes --> W1s["git push -u"]
        W1s --> W1t{Success}
        W1t -- No --> W1k
        W1t -- Yes --> W1v["SUCCESS"]
    end

    subgraph "Workflow 2: Bind Local to Remote"
        W2 --> W2a["Select local project"]
        W2a --> W2b{"Binding method"}
        W2b -- "Create NEW" --> W2c["Select platforms"]
        W2b -- "Connect EXISTING" --> W2l["Enter URLs"]
        W2l --> W2m["_clone_existing_remote binding"]
        W2m --> W2p["sync_with_remote\nDivergence Handler"]
        W2p --> W2q{Scenario}
        W2q -- "Remote ahead" --> W2s["Rebase Merge Skip"]
        W2s --> W2t{User choice}
        W2t -- 1 --> W2u["git stash + rebase"]
        W2t -- 2 --> W2y["git merge --no-edit"]
    end

    subgraph "Safety Mechanisms"
        W4 --> W4a{"Delete choice"}
        W4a -- "Delete BOTH" --> W4f["Type project name"]
        W4f --> W4g{Match}
        W4g -- Yes --> W4i["Type DELETE"]
        W4i --> W4j{Match}
        W4j -- Yes --> W4k["API DELETE remote"]
    end


```    
## Issues and Contact
I am not fully available, although you can email me, but I cannot respond immediately, the cycle of improvement and issues tracking would be over a month. 
For those who are willing to file an issue in GitHub/GitLab, please file all issues collectively you believe about the functioning of script, such as vulnerabilities, bugs, feature-request, etc., instead of separately filling issues for each problem, that is collectively everything exhaustively, and also avoid to file similar issues, Either comment in exisitng issue or leave as is. 
Thank you for your understanding.

## License

This project uses multiple licenses for different components:

*   **Source Code**: The `repo-crafter.sh` script is licensed under the **GNU General Public License v3.0** (GPLv3).
*   **Technical Documentation**: The file `Code_Documentation.md` is licensed under the **Creative Commons Attribution-ShareAlike 4.0 International License** (CC BY-SA 4.0).
*   **User Guide**: The file `User_Manual.md` is licensed under the **Creative Commons Attribution 4.0 International License** (CC BY 4.0).

For full license texts, please see the `LICENSE.md` file and the notices at the top of each documentation file.
