# Interactive-git-helper-shell-script

<div style="background-color: #ffbf00; border-left: 4px solid #ffbf00; padding: 16px; margin: 20px 0; border-radius: 6px; color: #000000;">
<strong style="color: #000000;">🛑 Caution</strong><br>
<span style="color: #ffffff;">Although this code has been reviewed, it has been tailored with AI LLM assistance and some features still require testing, so still under development. The code has to be refactored further. Please review the code thoroughly before use. You can refer to the other documentation files if necessary.</span>
</div>

## Navigation flow diagram

```mermaid
flowchart TD
    Start[Start Script] --> MainMenu
    
    subgraph MainMenu [Main Menu]
        A1[1. Create New Project] --> A1_Sub
        A2[2. Convert Local → Remote]
        A3[3. Convert Remote → Local]
        A4[4. Manage/Delete Project]
        A5[5. List Remote Repositories]
        A6[6. Configure .gitignore]
        A7[7. Test Configuration]
        A8[8. Exit]
    end

    A1_Sub --> B1[New Local + Remote]
    A1_Sub --> B2[Clone Existing Remote]
    A1_Sub --> B3[Local-Only Project]

    B1 --> C1[Name & Platform]
    C1 --> C2[Create Local Dir & Init Git]
    C2 --> C3[API: Create Remote Repo]
    C3 --> C4[Add Remote & Push]
    C4 --> End1[Project Created ✅]

    A4 --> D1{Delete Choice}
    D1 --> D2[Local Copy Only]
    D1 --> D3[Unbind to Local]
    D1 --> D4[Delete Both]
    
    D4 --> D4_Confirm{Type Name to Confirm}
    D4_Confirm -->|Confirmed| D4_API[API: Delete Remote]
    D4_API --> D4_Local[Delete Local Files]
    D4_Local --> End2[Fully Deleted ✅]

    style Start fill:#e1f5e1
    style End1 fill:#e1f5e1
    style End2 fill:#e1f5e1
```

## Functional/Processes Flow diagram

```mermaid
flowchart LR
    subgraph Config[Configuration Layer]
        direction TB
        C1[platforms.conf] --> C2[load_platform_config]
        C2 --> Arrays[Platform Arrays<br/>PLATFORM_API_BASE, etc.]
    end

    subgraph Core[Core Logic Layer]
        direction TB
        L1[User Input & Menu] --> L2[select_platforms]
        L2 --> L3[Platform API Calls]
        L3 --> L4[Git Operations]
    end

    subgraph API[API Communication]
        direction TB
        A1[platform_api_call] --> A2{Curl Request}
        A2 --> A3[Parse JSON with jq]
        A3 --> A4[Return SSH URL/Data]
    end

    subgraph Git[Git & FS Operations]
        direction TB
        G1[Directory Creation] --> G2[git init/add/commit]
        G2 --> G3[git remote add]
        G3 --> G4[git push]
    end

    Config --> Core
    Core --> API
    Core --> Git
    
    style Config fill:#f0f8ff
    style Core fill:#fff0f5
    style API fill:#f0fff0
    style Git fill:#fffaf0
```

## More detailed Functional Diagram

```mermaid
flowchart TD
    A["main()"] --> B["check essential tools"]
    B --> C["load_platform_config()"]
    C --> D["Parse platforms.conf"]
    D --> E["Populate platform arrays<br/>PLATFORM_API_BASE, etc."]
    E --> F["Build AVAILABLE_PLATFORMS list"]
    F --> G["is_safe_directory()"]
    G --> H["main_menu() loop"]

    H --> I{"User selects option"}

    I -- "Option 1" --> J["create_new_project_workflow()"]
    I -- "Option 2" --> K["convert_local_to_remote_workflow()"]
    I -- "Option 3" --> L["convert_remote_to_local_workflow()"]
    I -- "Option 4" --> M["manage_project_workflow()"]
    I -- "Option 5" --> N["list_remote_repos_workflow()"]
    I -- "Option 6" --> O["gitignore_maker_interactive()"]
    I -- "Option 7" --> P["test_platform_config()"]
    I -- "Option 8" --> Q["Exit"]

    J --> J1["_create_with_new_remote()<br/>_clone_existing_remote()<br/>_create_local_only()"]
    K --> K1["_select_project_from_dir()"]
    K1 --> K2["select_platforms()"]
    K2 --> K3["Add git remote(s)"]
    
    L --> L1["_select_project_from_dir()"]
    L1 --> L2["Remove all git remotes"]
    L2 --> L3["Move to LOCAL_ROOT"]

    M --> M1["_delete_local_copy()<br/>_delete_both()"]
    M1 --> M2["platform_api_call()<br/>(DELETE request)"]

    N --> N1["select_platforms()"]
    N1 --> N2["list_remote_repos()"]
    N2 --> N3["platform_api_call()"]

    O --> O1["gitignore_maker()"]
    O1 --> O2["_select_and_template_files()"]

    P --> P1["check_ssh_auth()"]
    P1 --> P2["select_platforms() test"]

    subgraph API_CALLS ["Core API & Git Operations"]
        S1["create_remote_repo()"] --> S2["platform_api_call()"]
        S3["check_remote_exists()"] --> S4["platform_api_call()"]
        S5["warn_similar_remote_repos()"] --> S6["platform_api_call()"]
        
        S2 --> S7["Curl with auth_header<br/>from config"]
        S7 --> S8["Parse JSON with jq"]
    end

    J1 --> API_CALLS
    N3 --> API_CALLS
    M2 --> API_CALLS

    style A fill:#e1f5e1
    style Q fill:#ffebee
    style API_CALLS fill:#f0f8ff,stroke:#333,stroke-width:2px
```

## Issues and Contact
I am not fully available, although you can email me, but I cannot respond immediately, the cycle of improvement and issues would be over a month. For those who are willing to file an issue in GitHub, please file all issues you have in mind instead of separately filling issues for each problem, so that it collect everything exhaustively, and also avoid to file similar issues, Either comment in exisitng issue or leave as is. Thank you for your understanding.

## License

This project uses multiple licenses for different components:

*   **Source Code**: The `repo-crafter.sh` script is licensed under the **GNU General Public License v3.0** (GPLv3).
*   **Technical Documentation**: The file `Code_Documentation.md` is licensed under the **Creative Commons Attribution-ShareAlike 4.0 International License** (CC BY-SA 4.0).
*   **User Guide**: The file `User_Manual.md` is licensed under the **Creative Commons Attribution 4.0 International License** (CC BY 4.0).

For full license texts, please see the `LICENSE.md` file and the notices at the top of each documentation file.
