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
    Args -- "--dry-run / -n" --> Dry[DRY-RUN Mode<br/>Preview Only]
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

    M1_Sub --> C1[Create Local + Remote<br/>_create_with_new_remote()]
    M1_Sub --> C2[Clone Existing Remote<br/>_clone_existing_remote()]
    M1_Sub --> C3[Create Local-Only<br/>_create_local_only()]

    C1 --> C1a[DRY_RUN Check<br/>Exit if true]
    C1a --> C1b[Create Remote via API]
    C1b --> C1c{Success?}
    C1c -- No --> C1d[_cleanup_failed_creation()<br/>Atomic rollback]
    C1d --> C1z[Return to Menu]
    C1c -- Yes --> C1e[Initialize Local Git]
    C1e --> C1f[Create REMOTE_STATE.yml]
    C1f --> C1g[Push to Remote]
    C1g --> C1h{DRY_RUN?}
    C1h -- Yes --> C1i[preview_and_abort_if_dry()<br/>EXIT SCRIPT]
    C1h -- No --> C1j[✅ Project Created]

    C2 --> C2a[DRY_RUN Check]
    C2a --> C2b[Parse Git URL]
    C2b --> C2c[Detect Platform]
    C2c --> C2d[SSH Auth Check]
    C2d --> C2e{Success?}
    C2e -- No --> C2z[Return]
    C2e -- Yes --> C2f[git clone]
    C2f --> C2g[Echo dest_dir]
    C2g --> C2h[Return to Caller]

    C3 --> C3a[Create Directory]
    C3a --> C3b[git init -b main]
    C3b --> C3c[Remove Remotes]
    C3c --> C3d[Create README]
    C3d --> C3e[DRY_RUN?]
    C3e -- Yes --> C3f[EXIT SCRIPT]
    C3e -- No --> C3g[✅ Local-Only Created]

    M2 --> M2a{Binding Method}
    M2a -- "Create NEW repos" --> M2b[Select Platform(s)]
    M2b --> M2c[warn_similar_remote_repos()]
    M2c --> M2d[Create remotes via API]
    M2d --> M2e[handle_existing_remote()<br/>Conflict Check]
    M2e -- Conflict --> M2f[Prompt: Update Remote?]
    M2f -- No --> M2g[Skip Platform]
    M2f -- Yes --> M2h[git remote set-url]
    M2h --> M2i[git push -u]
    M2i --> M2j{DRY_RUN?}
    M2j -- Yes --> M2k[EXIT SCRIPT]
    M2j -- No --> M2l[✅ Bound]

    M2a -- "Connect EXISTING" --> M2m[Parse & Validate URLs]
    M2m --> M2n[_clone_existing_remote("binding")]
    M2n --> M2o{Clone Success?}
    M2o -- No --> M2z[Return]
    M2o -- Yes --> M2p[Copy Local Files]
    M2p --> M2q[sync_with_remote()<br/>Divergence Handling]
    M2q --> M2r{Rebase/Merge/Skip}
    M2r --> M2s[DRY_RUN?]
    M2s -- Yes --> M2k
    M2s -- No --> M2t[✅ Bound]

    M3 --> M3a[Select Remote Project]
    M3a --> M3b[git remote -v]
    M3b --> M3c[Execute Dangerous<br/>Remove All Remotes]
    M3c --> M3d[Delete REMOTE_STATE.yml]
    M3d --> M3e[mv to Local_Projects/]
    M3e --> M3f[DRY_RUN?]
    M3f -- Yes --> M3g[EXIT SCRIPT]
    M3f -- No --> M3h[✅ Unbound]

    M4 --> M4a{Delete Choice}
    M4a -- "1) Local only" --> M4b[execute_dangerous<br/>rm -rf]
    M4b --> M4c[DRY_RUN?]
    M4c -- Yes --> M4d[EXIT SCRIPT]
    M4c -- No --> M4e[✅ Deleted]

    M4a -- "2) Unbind" --> M3

    M4a -- "3) Delete BOTH" --> M4f[Prompt: Type Project Name]
    M4f --> M4g{Match?}
    M4g -- No --> M4z[Cancel]
    M4g -- Yes --> M4h[Prompt: Type DELETE]
    M4h --> M4i{Match?}
    M4i -- No --> M4z
    M4i -- Yes --> M4j[API: DELETE Remote]
    M4j --> M4k{Success?}
    M4k -- No --> M4l[⚠️ Keep Local]
    M4k -- Yes --> M4m[execute_dangerous<br/>rm -rf local]
    M4m --> M4n[DRY_RUN?]
    M4n -- Yes --> M4o[EXIT SCRIPT]
    M4n -- No --> M4p[✅ Fully Deleted]

    M5 --> M5a[Select Platform(s)]
    M5a --> M5b[API: List Repos]
    M5b --> M5c{Success?}
    M5c -- No --> M5d[❌ Failed]
    M5c -- Yes --> M5e[Display Repos]
    M5e --> M5f[Press Enter]

    M6 --> M6a[Enter Project Directory]
    M6a --> M6b{Existing .gitignore?}
    M6b -- Yes --> M6c[4 Options: Edit/Backup/Append/Cancel]
    M6c -- Cancel --> M6z[Return]
    M6c --> M6d[Select Pattern Source]
    M6b -- No --> M6d
    M6d --> M6e[Add Patterns]
    M6e --> M6f{Mode?}
    M6f -- 1) Simple --> M6g[Stage & Commit]
    M6g --> M6h[DRY_RUN?]
    M6h -- Yes --> M6i[EXIT SCRIPT]
    M6h -- No --> M6j[✅ Done]

    M6f -- 2) Cautious --> M6k[nano .gitignore]
    M6k --> M6g

    M6f -- 3) Local-only --> M6l[mv to .git/info/exclude]
    M6l --> M6h

    M1h --> M1j
    M2l --> M2j
    M3h --> M3j
    M4e --> M4q
    M4p --> M4q
    M5f --> M5g[Return]
    M6j --> M6m[Return]

    style Start fill:#e1f5e1,stroke:#2e7d32
    style Test fill:#fff3cd,stroke:#f57c00
    style Dry fill:#fff3cd,stroke:#f57c00
    style Help fill:#e3f2fd,stroke:#1976d2
    style M1j fill:#e1f5e1,stroke:#2e7d32
    style M2t fill:#e1f5e1,stroke:#2e7d32
    style M3h fill:#e1f5e1,stroke:#2e7d32
    style M4e fill:#e1f5e1,stroke:#2e7d32
    style M4p fill:#ffebee,stroke:#c62828
    style M6j fill:#e1f5e1,stroke:#2e7d32
    style M4f fill:#ffebee,stroke:#c62828
    style M6l fill:#fff3cd,stroke:#f57c00
    style M2q fill:#fff3cd,stroke:#f57c00
    style M2e fill:#fff3cd,stroke:#f57c00
    style M1i fill:#fff3cd,stroke:#f57c00
    style M2k fill:#fff3cd,stroke:#f57c00
    style M3g fill:#fff3cd,stroke:#f57c00
    style M4d fill:#fff3cd,stroke:#f57c00
    style M6h fill:#fff3cd,stroke:#f57c00
```

## Functional/Processes Flow diagram

```mermaid
flowchart TD
    subgraph "Entry & Initialization"
        A["main()"] --> B["parse_args()<br/>DRY_RUN? TEST? HELP?"]
        B --> C["check essential tools<br/>git, curl, jq, ssh"]
        C --> D["load_platform_config()<br/>Parse platforms.conf"]
        D --> E["Populate 15+ PLATFORM_* arrays"]
        E --> F["Build AVAILABLE_PLATFORMS list"]
        F --> G["is_safe_directory()"]
        G --> H["Offer --test run"]
        H --> I["main_menu() loop"]
    end

    subgraph "Core Workflow Dispatch"
        direction TB
        I --> J1["1) 🆕 Create New Project"]
        I --> J2["2) 🔗 Convert Local → Remote"]
        I --> J3["3) 🔓 Convert Remote → Local"]
        I --> J4["4) 🗑️ Manage/Delete Project"]
        I --> J5["5) 📋 List Remote Repositories"]
        I --> J6["6) ⚙️ Configure .gitignore"]
        I --> J7["7) 🧪 Test Configuration"]
        I --> J8["8) ℹ️ About / 9) 🚪 Exit"]

        J1 --> W1["create_new_project_workflow()"]
        J2 --> W2["convert_local_to_remote_workflow()"]
        J3 --> W3["convert_remote_to_local_workflow()"]
        J4 --> W4["manage_project_workflow()"]
        J5 --> W5["list_remote_repos_workflow()"]
        J6 --> W6["gitignore_maker_interactive()"]
        J7 --> W7["test_platform_config()"]
    end

    subgraph "Workflow 1: Create New Project"
        W1 --> W1a{"How to start?"}
        W1a -- "1) Local+Remote" --> W1b["_create_with_new_remote()"]
        W1a -- "2) Clone Remote" --> W1c["_clone_existing_remote('standalone')"]
        W1a -- "3) Local-Only" --> W1d["_create_local_only()"]

        W1b --> W1e{DRY_RUN?}
        W1e -- Yes --> W1f[Accumulate DRY_RUN_ACTIONS]
        W1f --> W1y[preview_and_abort_if_dry()<br/>EXIT SCRIPT]
        W1e -- No --> W1g[platform_api_call POST]
        W1g --> W1h{HTTP Success?}
        W1h -- No --> W1i{owner_not_found_patterns match?}
        W1i -- Yes --> W1j[Try fallback user]
        W1j -- Fail --> W1k[_cleanup_failed_creation()]
        W1k --> W1z[Return 1]
        W1i -- No --> W1k
        W1h -- Yes --> W1l[Extract ssh_url fields]
        W1l --> W1m{ssh_url found?}
        W1m -- No --> W1n[Use template fallback]
        W1m -- Yes --> W1o[Create local dir]
        W1o --> W1p[git init -b default_branch]
        W1p --> W1q[git add README.md & commit]
        W1q --> W1r[git remote add]
        W1r --> W1s[git push -u]
        W1s --> W1t{Push success?}
        W1t -- No --> W1k
        W1t -- Yes --> W1u[create_multi_platform_manifest()]
        W1u --> W1v[✅ SUCCESS]

        W1c --> W1w[Parse URL & Detect Platform]
        W1w --> W1x[check_ssh_auth()]
        W1x --> W1aa{Auth success?}
        W1aa -- No --> W1z
        W1aa -- Yes --> W1ab[git clone]
        W1ab --> W1ac[Echo dest_dir]
        W1ac --> W1ad[Return to Menu]

        W1d --> W1ae[mkdir & git init -b main]
        W1ae --> W1af[remove_existing_remotes()]
        W1af --> W1ag[Create README]
        W1ag --> W1ah[DRY_RUN?]
        W1ah -- Yes --> W1y
        W1ah -- No --> W1ai[✅ Local-Only Created]
    end

    subgraph "Workflow 2: Bind Local to Remote"
        W2 --> W2a[Select local project]
        W2a --> W2b{"Binding method?"}
        W2b -- "Create NEW repos" --> W2c[Select platform(s)]
        W2c --> W2d[warn_similar_remote_repos()]
        W2d --> W2e[Select visibility]
        W2e --> W2f[Loop: create_remote_repo()]
        W2f --> W2g[handle_existing_remote()<br/>Check for conflicts]
        W2g -- Conflict --> W2h{Update remote?}
        W2h -- No --> W2i[Skip platform]
        W2h -- Yes --> W2j[git remote set-url]
        W2j --> W2k[git push -u]
        W2g -- No Conflict --> W2k
        W2b -- "Connect EXISTING" --> W2l[Enter URLs]
        W2l --> W2m[_clone_existing_remote("binding")]
        W2m --> W2n{Clone success?}
        W2n -- No --> W2z[Return]
        W2n -- Yes --> W2o[Copy local files]
        W2o --> W2p[sync_with_remote()<br/>Dynamic branch detection<br/>Divergence Handler]
        W2p --> W2q{Scenario}
        W2q -- "Identical" --> W2r[Confirm push]
        W2q -- "Local ahead" --> W2r
        W2q -- "Remote ahead" --> W2s[Show: Rebase/Merge/Skip]
        W2s --> W2t{User choice}
        W2t -- 1) Rebase --> W2u[git stash + rebase]
        W2u --> W2v{Success?}
        W2v -- No --> W2w[Manual resolve + stash pop]
        W2v -- Yes --> W2x[Pop stash + push]
        W2t -- 2) Merge --> W2y[git merge --no-edit]
        W2y --> W2z2{Success?}
        W2z2 -- No --> W2w
        W2z2 -- Yes --> W2x
        W2t -- 3) Skip --> W2x
        W2t -- x) Cancel --> W2aa[Return 1]
        W2r --> W2ab[git push -u]
        W2x --> W2ab
        W2ab --> W2ac[DRY_RUN?]
        W2ac -- Yes --> W2ad[EXIT SCRIPT]
        W2ac -- No --> W2ae[✅ Bound]
    end

    subgraph "Workflow 3: Unbind Remote to Local"
        W3 --> W3a[Select remote project]
        W3a --> W3b[git remote -v]
        W3b --> W3c[execute_dangerous<br/>Remove all remotes]
        W3c --> W3d[Delete REMOTE_STATE.yml]
        W3d --> W3e[execute_dangerous<br/>mv to Local_Projects/]
        W3e --> W3f[DRY_RUN?]
        W3f -- Yes --> W3g[EXIT SCRIPT]
        W3f -- No --> W3h[✅ Unbound]
    end

    subgraph "Workflow 4: Delete Project"
        W4 --> W4a{"Delete choice"}
        W4a -- "1) Local only" --> W4b[execute_dangerous<br/>rm -rf]
        W4b --> W4c[DRY_RUN?]
        W4c -- Yes --> W4d[EXIT SCRIPT]
        W4c -- No --> W4e[✅ Deleted]
        W4a -- "2) Unbind" --> W3
        W4a -- "3) Delete BOTH" --> W4f[Prompt: Type exact project name]
        W4f --> W4g{Match?}
        W4g -- No --> W4h[Cancel]
        W4g -- Yes --> W4i[Prompt: Type DELETE]
        W4i --> W4j{Match?}
        W4j -- No --> W4h
        W4j -- Yes --> W4k[API: DELETE remote]
        W4k --> W4l{Success?}
        W4l -- No --> W4m[Keep local, abort]
        W4l -- Yes --> W4n[execute_dangerous<br/>rm -rf local]
        W4n --> W4o[DRY_RUN?]
        W4o -- Yes --> W4d
        W4o -- No --> W4p[✅ Fully Deleted]
    end

    subgraph "Workflow 5: List Repositories"
        W5 --> W5a[Select platform(s)]
        W5a --> W5b[platform_api_call GET]
        W5b --> W5c{Success?}
        W5c -- No --> W5d[❌ Failed message]
        W5c -- Yes --> W5e[jq parse & display]
        W5e --> W5f[Return to Menu]
    end

    subgraph "Workflow 6: Gitignore Manager"
        W6 --> W6a[Enter project directory]
        W6a --> W6b{Existing .gitignore?}
        W6b -- Yes --> W6c[4 Options: Edit/Backup/Append/Cancel]
        W6c -- Cancel --> W6z[Return 1]
        W6b -- No --> W6d[Select pattern source]
        W6c --> W6d
        W6d --> W6e[Add patterns loop]
        W6e --> W6f{Mode: 1) Simple 2) Cautious 3) Local-only}
        W6f -- 1 --> W6g[Stage & commit .gitignore]
        W6g --> W6h[DRY_RUN?]
        W6h -- Yes --> W6i[EXIT SCRIPT]
        W6h -- No --> W6j[Create .gitignore.template]
        W6j --> W6k[✅ Done (return 0)]
        W6f -- 2 --> W6l[nano .gitignore]
        W6l --> W6g
        W6f -- 3 --> W6m[mv to .git/info/exclude]
        W6m --> W6n[Return "exclude"]
    end

    W1v --> W1ak[Return to Menu]
    W1ad --> W1ak
    W1ai --> W1ak
    W2ae --> W2af[Return to Menu]
    W2aa --> W2af
    W2z --> W2af
    W3h --> W3i[Return to Menu]
    W4e --> W4q[Return to Menu]
    W4p --> W4q
    W4h --> W4q
    W5f --> W5g[Return to Menu]
    W6k --> W6o[Return to Menu]
    W6z --> W6o

    style W1y fill:#fff3cd,stroke:#f57c00
    style W2ad fill:#fff3cd,stroke:#f57c00
    style W3g fill:#fff3cd,stroke:#f57c00
    style W4d fill:#fff3cd,stroke:#f57c00
    style W6i fill:#fff3cd,stroke:#f57c00
    style W1k fill:#ffebee,stroke:#c62828
    style W2aa fill:#ffebee,stroke:#c62828
    style W4h fill:#ffebee,stroke:#c62828
    style W4p fill:#ffebee,stroke:#c62828
    style W2s fill:#fff3cd,stroke:#f57c00
    style W1v fill:#e1f5e1,stroke:#2e7d32
    style W2ae fill:#e1f5e1,stroke:#2e7d32
    style W3h fill:#e1f5e1,stroke:#2e7d32
    style W4e fill:#e1f5e1,stroke:#2e7d32
    style W6j fill:#e1f5e1,stroke:#2e7d32
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
