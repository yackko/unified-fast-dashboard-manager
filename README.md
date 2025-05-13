# unified-fast-dashboard-manager

# Unified Fast Dashboard Manager Script 

The `manage_dashboard.sh` script (this utility) is a powerful Bash tool designed to simplify and accelerate the development of Go-based Fyne GUI dashboard applications. It provides an interactive command-line interface for two primary functions:

1.  **Scaffold a New "Fast Dashboard" Project**: Generates a complete, runnable Fyne application boilerplate. This includes a well-defined project structure, a sample widget that works out-of-the-box, and special "hooks" in the main layout file to enable easy, semi-automated integration of future widgets. During setup, it will prompt you for your preferred initial window dimensions.
2.  **Add Features to an Existing Project**: Once a project is created, this script (a copy of which is placed inside your new project) helps you easily add new components. It uses a user-friendly menu to guide you through adding:
    * New Pages or Full Sections (UI Modules)
    * New Widgets or Info Boxes for the main dashboard (with attempted auto-integration)
    * Data Handlers or External Source Connections (Services - Advanced)
    * New Types of Information to Manage (Data Models - Advanced)

## Prerequisites

* **Bash:** A Bash-compatible shell environment (standard on Linux and macOS; Windows users can utilize WSL - Windows Subsystem for Linux, or Git Bash).
* **Go:** A working Go programming language installation (version 1.18 or newer is recommended). You can download it from [golang.org](https://golang.org/dl/).
* **Fyne Dependencies:** To compile and run Fyne GUI applications, certain system libraries are required. Please consult the official Fyne documentation for installation instructions specific to your operating system: [Fyne Developer Setup Guide](https://developer.fyne.io/started/)

## How to Use

### 1. Initial Setup (Getting the Script)

* **Save the Script:** Download or copy the `unified_dashboard_manager.sh` script (from the `unified_dashboard_manager_v4_sh` artifact) to a convenient and accessible location on your system. This will be your "master" copy of the script.
* **Make it Executable:** Open your terminal, navigate to the directory where you saved the script, and run:
    ```bash
    chmod +x unified_dashboard_manager.sh
    ```

### 2. Running the Script

The script operates in two main modes:

* **A. To Create a New Dashboard Project:**
    1.  Open your terminal and navigate to the parent directory where you want your new project folder to be created.
    2.  Execute the master script: `./path/to/your/global/unified_dashboard_manager.sh`
    3.  From the main menu, choose option `1` ("Create a new Fast Dashboard project").
    4.  Follow the on-screen prompts to:
        * Enter a name for your new project (e.g., "My Awesome Dashboard").
        * Specify the initial window width (e.g., `1280`).
        * Specify the initial window height (e.g., `720`).
    5.  The script will then:
        * Create a new directory with your project's name.
        * Generate all the boilerplate files and subdirectories.
        * **Copy itself** into the root of this newly created project, naming the copy `manage_dashboard.sh`. This copied script is what you'll use for future modifications to *that specific project*.

* **B. To Add Features to an Existing Dashboard Project:**
    1.  Open your terminal and **navigate into the root directory** of an existing "Fast Dashboard" project (one that was previously created by this script).
    2.  Run the `manage_dashboard.sh` script that was copied into that project: `./manage_dashboard.sh`
    3.  From the main menu, choose option `2` ("Add features to an existing Fast Dashboard project").
    4.  You will be presented with a user-friendly menu to select the type of feature you wish to add. Follow the prompts for the chosen feature.

## Generated Project Structure

Creating a new project with this script will result in the following directory structure:



your-project-name/
├── cli/                        # For command-line interface related code (e.g., flags)
│   └── flags.go
├── core/                       # Core application logic, business rules
│   └── app_logic.go
├── generators/                 # (Optional) If you decide to add your own code generators
│   └── widget_generator.go
├── go.mod                      # Go module definition file
├── internal/                   # Private application code, not intended for external use
│   ├── config/                 # For application configuration loading/management
│   │   └── loader.go
│   ├── models/                 # Data structure definitions (structs)
│   │   └── example_model.go
│   ├── services/               # For business logic, API clients, data processing
│   │   └── data_service.go
│   └── ui/                     # All User Interface related code
│       ├── layout/             # Defines the main application window layout
│       │   └── main_layout.go  (Contains auto-integration hooks for widgets)
│       ├── modules/            # For distinct UI pages, sections, or full views
│       └── widgets/            # For individual, reusable dashboard widgets
│           └── sample_widget.go (A working example widget, integrated by default)
├── main.go                     # The main entry point for your Fyne application
├── manage_dashboard.sh         # A copy of this utility script for easy feature addition
├── templates/                  # (Optional) For Go code templates if using generators
│   └── widget_template.go
└── utils/                      # General utility/helper functions
└── helpers.go


**Key Generated Files:**

* **`main.go`**: Initializes the Fyne application and the main window. The `WindowWidth` and `WindowHeight` constants here are set based on your input during project creation.
* **`internal/ui/layout/main_layout.go`**: This crucial file defines the primary layout of your dashboard (e.g., toolbars, content area). It contains special comment "hooks" like `// AUTO_IMPORTS_START`, `// AUTO_WIDGET_INSTANTIATIONS_START`, and `// AUTO_WIDGET_LIST_START` (and their `_END` counterparts). These hooks are essential for the script's ability to attempt automatic integration of new dashboard widgets.
* **`internal/ui/widgets/sample_widget.go`**: A simple, functional Fyne widget that is automatically included and displayed in your new dashboard to demonstrate the structure and provide an immediate visual.

## Adding Features (User-Friendly Menu)

When you choose to add features to an existing project, the script presents the following menu:



What kind of feature would you like to add to your dashboard?

Add a new PAGE or full SECTION to the dashboard
(e.g., a 'Settings' page, a 'User Profile' area, or a 'Detailed Reports' view)

Add a new WIDGET or small INFO BOX to the main dashboard screen
(e.g., a clock, a weather display, a quick notes area, a data summary)

Add a way to HANDLE DATA or connect to an EXTERNAL SOURCE (Advanced)
(e.g., to fetch data from a website, save user preferences, perform calculations)

Define a new TYPE OF INFORMATION the dashboard will manage (Advanced)
(e.g., a 'customer' record, a 'project' entry, a 'to-do item' structure)

Back to Main Menu / Exit


1.  **Add a new PAGE or full SECTION (UI Module):**
    * Creates placeholder Go files (e.g., `view.go`, `logic.go`) in a new subdirectory under `internal/ui/modules/your_page_name/`.
    * **Action Required:** You must manually implement the UI and logic for this new page. More importantly, you'll need to add a way to navigate to it (e.g., by adding a button to the toolbar or a sidebar in `internal/ui/layout/main_layout.go` and updating the main content area when this button is clicked).

2.  **Add a new WIDGET or small INFO BOX:**
    * Creates a placeholder Go file for your widget in `internal/ui/widgets/your_widget_name_widget.go`.
    * **Automatic Integration Attempt:** The script will try to modify `internal/ui/layout/main_layout.go` to:
        * Add the necessary import for the `widgets` package (if not already present).
        * Add a line to create an instance of your new widget.
        * Add this new widget instance to the list of widgets displayed on the dashboard.
    * **Action Required:** After the script runs, always review `internal/ui/layout/main_layout.go` to confirm the changes. Then, implement the actual UI and logic for your new widget in its generated file.

3.  **Add a way to HANDLE DATA or connect to an EXTERNAL SOURCE (Service - Advanced):**
    * Creates a placeholder Go file in `internal/services/your_service_name_service.go`.
    * **Action Required:** This is a more advanced feature. You will need to:
        1.  Implement the actual data handling or API interaction logic in the generated service file.
        2.  Instantiate this service in your application (often in `main.go` or a core application setup file).
        3.  Call the service's methods from your UI components (widgets, modules) or other parts of your application as needed.

4.  **Define a new TYPE OF INFORMATION (Data Model - Advanced):**
    * Creates a placeholder Go file in `internal/models/your_model_name_model.go`.
    * **Action Required:**
        1.  Define the specific fields (properties) for this type of information in the generated model file (e.g., for a "Task" model, you might add `Title string`, `IsDone bool`, `DueDate time.Time`).
        2.  Use this new data structure within your services (for storage/retrieval) and UI components (for display/interaction).
        3.  If you plan to use a database, you'll need to integrate this model with your database setup and handle any necessary schema migrations.

## Developing Your Dashboard Application

After generating a new project or adding a new feature:

1.  **Navigate to your project's root directory:** `cd your-project-name`
2.  **Tidy Go Modules:** Run `go mod tidy`. This command analyzes your source code, finds all the packages it depends on, and ensures your `go.mod` and `go.sum` files are consistent. It will also download any missing dependencies (like Fyne).
3.  **Run the Application:** Execute `go run main.go`. This will compile and run your Fyne dashboard.
4.  **Implement Functionality:** The script generates placeholders. You'll need to:
    * Fill in the `// TODO:` sections in the generated files.
    * Write the actual Go code for your dashboard's features, UI elements, and logic.
5.  **Customize and Extend:**
    * Modify `internal/ui/layout/main_layout.go` to further customize the arrangement of components, add navigation elements (like sidebars or tabbed views), and refine the overall user experience.
    * Develop the logic within your widgets, modules, services, and models.

## Important Notes

* **Auto-Integration Hooks:** The automatic integration of new dashboard widgets into `internal/ui/layout/main_layout.go` depends on the presence of specific comment lines (e.g., `// AUTO_WIDGET_INSTANTIATIONS_START`). **Do not remove or significantly alter these comment hooks** if you want the script to continue attempting auto-integration.
* **`sed` Command:** The script uses `sed -i.bak` for in-place file editing (with a backup). This syntax is generally compatible with macOS/BSD and many Linux distributions. If you encounter issues with `sed` on your specific system, you might need to adjust this command (e.g., some Linux versions prefer `sed -i` without the `.bak`, or `sed -i ''` for BSD if the `.bak` causes issues).
* **Review Changes:** While the script aims for convenience, especially with widget auto-integration, always review the files it modifies (primarily `main_layout.go`) to ensure the changes are correct and as expected.

This script is intended to be a helpful starting point and a productivity booster for your Fyne dashboard projects. Happy coding!
