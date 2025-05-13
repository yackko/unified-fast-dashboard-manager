#!/bin/bash

# This script serves as a unified manager for Fast Dashboard projects.
# It can:
# 1. Generate a new Fast Dashboard Go Fyne project boilerplate with user-defined window size.
# 2. Add new features (UI modules, widgets, services, models) to an existing project.

echo "----------------------------------------------------"
echo " Unified Fast Dashboard Manager "
echo "----------------------------------------------------"
echo ""

# --- Configuration (mostly for "add feature" part) ---
UI_MODULES_PATH="internal/ui/modules"
UI_WIDGETS_PATH="internal/ui/widgets"
SERVICES_PATH="internal/services"
MODELS_PATH="internal/models"
LAYOUT_FILE_PATH="internal/ui/layout/main_layout.go"
SCRIPT_NAME_IN_PROJECT="manage_dashboard.sh" # Name of this script when copied to new projects

# --- Helper function to get the Go module name from go.mod ---
# To be called when inside a project directory
get_current_project_module_name() {
    if [ ! -f "go.mod" ]; then
        echo "[ERROR] go.mod not found. This operation requires being in the root of a Fast Dashboard project."
        return 1 # Error code
    fi
    MODULE_NAME=$(head -n 1 go.mod | awk '{print $2}')
    if [ -z "$MODULE_NAME" ]; then
        echo "[ERROR] Could not determine module name from go.mod."
        return 1 # Error code
    fi
    echo "$MODULE_NAME"
    return 0 # Success
}

# --- Helper function to create a Go file with package declaration and a comment ---
# $1: file_path
# $2: package_name
# $3: purpose_comment
# $4: feature_name_pascal_case (for struct/func names)
# $5: (Optional) specific_template_content (raw string)
# $6: (Optional) current_module_name_for_imports
create_go_file() {
    local file_path="$1"
    local package_name="$2"
    local purpose_comment="$3"
    local feature_name_pascal_case="$4"
    local specific_template_content="$5"
    local current_module_name_for_imports="$6"
    local dir_path

    dir_path=$(dirname "$file_path")

    if [ ! -d "$dir_path" ]; then
        mkdir -p "$dir_path"
        if [ $? -eq 0 ]; then
            echo "[SUCCESS] Created directory: ${dir_path}"
        else
            echo "[ERROR] Failed to create directory: ${dir_path}"
            return 1
        fi
    fi

    if [ -f "$file_path" ]; then
        echo "[INFO] File already exists: ${file_path}. Skipping."
    else
        if [ -z "$feature_name_pascal_case" ]; then
            # Basic PascalCase conversion
            feature_name_pascal_case=$(echo "$package_name" | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1' FS='[-_]' OFS='')
        fi

        if [ -n "$specific_template_content" ]; then
            # Use process substitution to pass multi-line content correctly
            printf "%s" "$specific_template_content" > "$file_path"
        else
            # Default template for sample_widget.go and other placeholders if no specific template given
            cat <<EOL > "$file_path"
package ${package_name}

// ${purpose_comment}
// Feature: ${feature_name_pascal_case}
// File: $(basename "$file_path")

import (
	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/widget"
	"fyne.io/fyne/v2/container"
	// "${current_module_name_for_imports}/internal/models" // Example import if module name is passed
)

// Example structure for a simple widget (adapt as needed for other types):
// For sample_widget.go, feature_name_pascal_case will be "Sample"
type ${feature_name_pascal_case} struct {
	widget.BaseWidget
	label *widget.Label
}

func New${feature_name_pascal_case}(win fyne.Window, app fyne.App) *${feature_name_pascal_case} {
	// The 'win' and 'app' parameters are examples; your component might not need them,
	// or might need other dependencies.
	s := &${feature_name_pascal_case}{}
	s.ExtendBaseWidget(s) // Important for custom Fyne widgets/components
	s.label = widget.NewLabel("Hello from ${feature_name_pascal_case} (Sample Widget)!")
	return s
}

func (s *${feature_name_pascal_case}) CreateRenderer() fyne.WidgetRenderer {
	return widget.NewSimpleRenderer(container.NewCenter(s.label))
}

// TODO: Implement more specific logic for this feature.
EOL
        fi
        if [ $? -eq 0 ]; then
            echo "[SUCCESS] Created Go file: ${file_path}"
        else
            echo "[ERROR] Failed to create Go file: ${file_path}"
        fi
    fi
}


# --- Logic for Generating a New Fast Dashboard Project ---
generate_new_dashboard_project() {
    echo ""
    echo "--- Create New Fast Dashboard Project ---"

    local current_script_abs_path
    current_script_abs_path="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

    if [ ! -f "$current_script_abs_path" ]; then
        current_script_abs_path="$0" 
        echo "[WARNING] Could not robustly determine absolute path of the running script. Using '$0'. Self-copy might be affected if script is not called with a clear path."
    fi

    read -r -p "Enter the name for your new Fast Dashboard project (e.g., my-dashboard): " PROJECT_NAME_INPUT

    if [ -z "$PROJECT_NAME_INPUT" ]; then
        echo "[ERROR] Project name cannot be empty. Aborting."
        return
    fi

    if [ -d "$PROJECT_NAME_INPUT" ]; then
        read -r -p "[WARNING] Directory '$PROJECT_NAME_INPUT' already exists. Overwrite? (yes/no): " OVERWRITE_CHOICE
        if [[ "$OVERWRITE_CHOICE" != "yes" ]]; then
            echo "Project creation cancelled by user."
            return
        fi
        echo "[INFO] Removing existing directory: $PROJECT_NAME_INPUT"
        rm -rf "$PROJECT_NAME_INPUT"
    fi

    echo "[INFO] Creating project: $PROJECT_NAME_INPUT"
    mkdir "$PROJECT_NAME_INPUT"
    local ORIGINAL_PROJECT_NAME="$PROJECT_NAME_INPUT"
    cd "$PROJECT_NAME_INPUT" || { echo "[ERROR] Failed to cd into $PROJECT_NAME_INPUT. Aborting."; return; }

    local SANITIZED_PROJECT_NAME=$(echo "$PROJECT_NAME_INPUT" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]' | sed 's/[^a-zA-Z0-9._-]//g')
    if [ -z "$SANITIZED_PROJECT_NAME" ]; then
        echo "[ERROR] Sanitized project name is empty. Please use a name with alphanumeric characters. Aborting."
        cd .. 
        return
    fi
    local MODULE_NAME="$SANITIZED_PROJECT_NAME"

    # --- Get Window Size ---
    local user_window_width
    local user_window_height
    local default_width="1024"
    local default_height="768"

    echo ""
    echo "--- Initial Window Size ---"
    read -r -p "Enter initial window width (default: ${default_width}): " user_window_width
    user_window_width=${user_window_width:-$default_width} 
    if ! [[ "$user_window_width" =~ ^[0-9]+$ ]] || [ "$user_window_width" -le 0 ]; then
        echo "[WARNING] Invalid width input. Must be a positive number. Using default: ${default_width}"
        user_window_width=$default_width
    fi

    read -r -p "Enter initial window height (default: ${default_height}): " user_window_height
    user_window_height=${user_window_height:-$default_height} 
    if ! [[ "$user_window_height" =~ ^[0-9]+$ ]] || [ "$user_window_height" -le 0 ]; then
        echo "[WARNING] Invalid height input. Must be a positive number. Using default: ${default_height}"
        user_window_height=$default_height
    fi
    echo "[INFO] Initial window size will be: ${user_window_width}x${user_window_height}"
    echo ""


    echo "[INFO] Creating core directories..."
    DIRECTORIES=("cli" "core" "generators" "templates" "utils" "internal/ui/layout" "internal/ui/widgets" "internal/ui/modules" "internal/config" "internal/services" "internal/models")
    for dir in "${DIRECTORIES[@]}"; do
        mkdir -p "$dir"
        echo "[SUCCESS] Created directory: $dir"
    done

    echo "[INFO] Creating go.mod with module name: ${MODULE_NAME}"
    cat <<EOL_GOMOD > go.mod
module ${MODULE_NAME}

go 1.21 // Or your preferred Go version

require fyne.io/fyne/v2 v2.4.0 // Example version, update as needed
EOL_GOMOD
    echo "[SUCCESS] Created go.mod"

    echo "[INFO] Creating main.go..."
    cat <<EOL_MAIN > main.go
package main

import (
	"${MODULE_NAME}/internal/ui/layout" 

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/app"
	// "fyne.io/fyne/v2/theme" 
)

// --- Application Configuration ---
const (
	AppID      = "com.example.${MODULE_NAME}" 
	AppName    = "${ORIGINAL_PROJECT_NAME} Dashboard"
	
	// Initial Window Size set during project creation.
	WindowWidth  float32 = ${user_window_width}
	WindowHeight float32 = ${user_window_height}
)

func main() {
	myApp := app.NewWithID(AppID)
	// myApp.Settings().SetTheme(theme.DarkTheme())

	myWindow := myApp.NewWindow(AppName)
	mainLayoutContent := layout.NewMainAppLayout(myWindow, myApp)

	myWindow.SetContent(mainLayoutContent)
	myWindow.Resize(fyne.NewSize(WindowWidth, WindowHeight))
	myWindow.SetMaster()
	myWindow.ShowAndRun()
}
EOL_MAIN
    echo "[SUCCESS] Created main.go with window size ${user_window_width}x${user_window_height}."

    echo "[INFO] Creating placeholder Go files..."
    create_go_file "cli/flags.go" "cli" "Handles command-line flags and arguments." "CliFlags" "" "$MODULE_NAME"
    create_go_file "core/app_logic.go" "core" "Core business logic." "AppLogic" "" "$MODULE_NAME"
    create_go_file "generators/widget_generator.go" "generators" "For custom widget generators." "WidgetGenerator" "" "$MODULE_NAME"
    create_go_file "templates/widget_template.go" "templates" "For Go code templates." "WidgetTemplate" "" "$MODULE_NAME"
    create_go_file "utils/helpers.go" "utils" "Utility functions." "Helpers" "" "$MODULE_NAME"
    create_go_file "internal/ui/widgets/sample_widget.go" "widgets" "Example custom Fyne widget." "Sample" "" "$MODULE_NAME"
    create_go_file "internal/config/loader.go" "config" "Loads application configuration." "ConfigLoader" "" "$MODULE_NAME"
    create_go_file "internal/services/data_service.go" "services" "Handles data interactions." "DataService" "" "$MODULE_NAME"
    create_go_file "internal/models/example_model.go" "models" "Example data model structure." "ExampleModel" "" "$MODULE_NAME"

    echo "[INFO] Creating internal/ui/layout/main_layout.go with auto-integration hooks and initial sample widget..."
    cat <<EOL_LAYOUT > "${LAYOUT_FILE_PATH}"
package layout

import (
	"fmt"
	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/widget"
	"fyne.io/fyne/v2/theme"
	// Import for the initial sample widget:
	"${MODULE_NAME}/internal/ui/widgets" 
	// AUTO_IMPORTS_START (do not remove or modify this line)
	// Other widget imports will be added here by the script
	// AUTO_IMPORTS_END (do not remove or modify this line)
)

// NewMainAppLayout creates the overall application layout.
func NewMainAppLayout(win fyne.Window, app fyne.App) fyne.CanvasObject {
	
	title := widget.NewLabel("Welcome to ${ORIGINAL_PROJECT_NAME}!")
	title.Alignment = fyne.TextAlignCenter

	// --- Automated Widget Integration Area ---
	// Instantiate the initial sample widget:
	sampleWidgetInstance := widgets.NewSample(win, app) // Calling NewSample as generated

	// AUTO_WIDGET_INSTANTIATIONS_START (do not remove or modify this line)
	// Other widget instantiations will be added here by the script
	// AUTO_WIDGET_INSTANTIATIONS_END (do not remove or modify this line)

	// List of widgets to display on the dashboard
	dashboardWidgets := []fyne.CanvasObject{
		sampleWidgetInstance, // Add the initial sample widget
		// AUTO_WIDGET_LIST_START (do not remove or modify this line)
		// Other widgets will be added to this list by the script
		// AUTO_WIDGET_LIST_END (do not remove or modify this line)
	}
	// --- End Automated Widget Integration Area ---

	var layoutItems []fyne.CanvasObject
	layoutItems = append(layoutItems, title)
	layoutItems = append(layoutItems, widget.NewSeparator())
	
	if len(dashboardWidgets) > 0 {
		widgetsVBox := container.NewVBox()
		for _, w := range dashboardWidgets {
			if w != nil { // Add a nil check for safety
				widgetsVBox.Add(w)
				widgetsVBox.Add(widget.NewSeparator()) 
			}
		}
		layoutItems = append(layoutItems, widget.NewLabelWithStyle("Dashboard Widgets:", fyne.TextAlignLeading, fyne.TextStyle{Bold: true}))
		layoutItems = append(layoutItems, widgetsVBox)
	} else {
		layoutItems = append(layoutItems, widget.NewLabel("No widgets added yet. Use './${SCRIPT_NAME_IN_PROJECT}' to add features."))
	}

	dashboardContentArea := container.NewScroll(container.NewVBox(layoutItems...))

	toolbar := widget.NewToolbar(
		widget.NewToolbarAction(theme.HomeIcon(), func() { fmt.Println("Home action for ${ORIGINAL_PROJECT_NAME}") }),
		widget.NewToolbarSeparator(),
		widget.NewToolbarAction(theme.SettingsIcon(), func() { fmt.Println("Settings action for ${ORIGINAL_PROJECT_NAME}") }),
	)

	return container.NewBorder(
		toolbar, 
		nil,     
		nil,     
		nil,     
		dashboardContentArea,
	)
}
EOL_LAYOUT
    echo "[SUCCESS] Created ${LAYOUT_FILE_PATH} with initial sample widget integrated."

    if [ -n "$current_script_abs_path" ] && [ -f "$current_script_abs_path" ]; then
        cp "$current_script_abs_path" "./${SCRIPT_NAME_IN_PROJECT}"
        chmod +x "./${SCRIPT_NAME_IN_PROJECT}"
        echo "[SUCCESS] Copied management script to './${SCRIPT_NAME_IN_PROJECT}'"
    else
        echo "[WARNING] Could not copy management script. Original script path determined as: '$current_script_abs_path'. Please copy it manually if needed."
    fi


    echo ""
    echo "----------------------------------------------------"
    echo "Fast Dashboard project '${ORIGINAL_PROJECT_NAME}' created successfully!"
    echo "Module name for go.mod: '${MODULE_NAME}'"
    echo "----------------------------------------------------"
    echo "Next steps:"
    echo "1. cd \"${ORIGINAL_PROJECT_NAME}\""
    echo "2. go mod tidy"
    echo "3. go run main.go"
    echo "4. To add features later, run './${SCRIPT_NAME_IN_PROJECT}' from within the '${ORIGINAL_PROJECT_NAME}' directory."
    echo "----------------------------------------------------"
    cd .. 
}


# --- Logic for Adding Features to an Existing Project ---
add_feature_to_existing_project() {
    echo ""
    echo "--- Add Feature to Existing Dashboard Project ---"
    
    local CURRENT_MODULE_NAME_FOR_ADD
    CURRENT_MODULE_NAME_FOR_ADD=$(get_current_project_module_name)
    if [ $? -ne 0 ]; then 
        echo "[ERROR] Could not proceed with adding features. Ensure you are in a project root with a valid go.mod."
        return
    fi
    echo "[INFO] Current project module: ${CURRENT_MODULE_NAME_FOR_ADD}"

    mkdir -p "$UI_MODULES_PATH"
    mkdir -p "$UI_WIDGETS_PATH"
    mkdir -p "$SERVICES_PATH"
    mkdir -p "$MODELS_PATH"

    while true; do
        echo ""
        echo "---------------------------------------------------------------------"
        echo "  What kind of feature would you like to add to your dashboard? "
        echo "---------------------------------------------------------------------"
        echo "  1. Add a new PAGE or full SECTION to the dashboard"
        echo "     (e.g., a 'Settings' page, a 'User Profile' area, or a 'Detailed Reports' view)"
        echo ""
        echo "  2. Add a new WIDGET or small INFO BOX to the main dashboard screen"
        echo "     (e.g., a clock, a weather display, a quick notes area, a data summary)"
        echo ""
        echo "  3. Add a way to HANDLE DATA or connect to an EXTERNAL SOURCE (Advanced)"
        echo "     (e.g., to fetch data from a website, save user preferences, perform calculations)"
        echo ""
        echo "  4. Define a new TYPE OF INFORMATION the dashboard will manage (Advanced)"
        echo "     (e.g., a 'customer' record, a 'project' entry, a 'to-do item' structure)"
        echo ""
        echo "  0. Back to Main Menu / Exit"
        echo "---------------------------------------------------------------------"
        read -r -p "Enter your choice [0-4]: " choice

        case $choice in
            1) generate_ui_module_feature "$CURRENT_MODULE_NAME_FOR_ADD" ;;
            2) generate_dashboard_widget_feature "$CURRENT_MODULE_NAME_FOR_ADD" ;;
            3) generate_service_feature "$CURRENT_MODULE_NAME_FOR_ADD" ;;
            4) generate_data_model_feature "$CURRENT_MODULE_NAME_FOR_ADD" ;;
            0) break ;;
            *) echo "[WARNING] Invalid choice. Please try again." ;;
        esac
    done
}

generate_ui_module_feature() {
    local current_module_name="$1"
    echo ""
    read -r -p "What do you want to call this new page/section? (e.g., User Profile, System Settings): " module_name_input
    local package_name=$(echo "$module_name_input" | tr '[:upper:]' '[:lower:]' | tr ' -' '_')
    local feature_name_clean=$(echo "$module_name_input" | sed 's/[^a-zA-Z0-9]//g')
    local feature_name_pascal=$(echo "$feature_name_clean" | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1' FS='[-_]' OFS='')

    if [ -z "$package_name" ]; then echo "[ERROR] Page/Section name cannot be empty."; return; fi

    local target_dir="${UI_MODULES_PATH}/${package_name}"
    echo "[INFO] Creating files for new page/section: ${module_name_input} (in ${target_dir}/)"
    
    local view_template_content; read -r -d '' view_template_content << EOM_VIEW
package ${package_name}

import (
	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/widget"
)

// New${feature_name_pascal}View creates the main view for the ${module_name_input} page/section.
func New${feature_name_pascal}View(win fyne.Window, app fyne.App) fyne.CanvasObject {
	// TODO: Build the actual content for your new page/section here.
	// This is a placeholder.
	return container.NewCenter(widget.NewLabel("Content for the '${module_name_input}' Page/Section"))
}
EOM_VIEW
    create_go_file "${target_dir}/view.go" "${package_name}" "Fyne UI view for ${module_name_input}." "${feature_name_pascal}" "$view_template_content" "$current_module_name"
    
    local logic_template_content; read -r -d '' logic_template_content << EOM_LOGIC
package ${package_name}

// Add any specific logic, data handling, or event handlers for the 
// '${module_name_input}' page/section here.
EOM_LOGIC
    create_go_file "${target_dir}/logic.go" "${package_name}" "Business logic for ${module_name_input}." "${feature_name_pascal}" "$logic_template_content" "$current_module_name"
    
    echo "[INFO] Files for page/section '${module_name_input}' created."
    echo "[ACTION REQUIRED] You'll need to manually add a way to navigate to this new page/section."
    echo "                  This usually involves adding a button to your main toolbar or sidebar in '${LAYOUT_FILE_PATH}'"
    echo "                  and updating the main content area when that button is clicked."
}

generate_dashboard_widget_feature() {
    local current_module_name="$1"
    echo ""
    read -r -p "What do you want to call this new widget/info box? (e.g., My Clock, Weather Info): " widget_name_input
    local file_prefix=$(echo "$widget_name_input" | tr '[:upper:]' '[:lower:]' | tr ' -' '_')
    local feature_name_clean=$(echo "$widget_name_input" | sed 's/[^a-zA-Z0-9]//g')
    local feature_name_pascal=$(echo "$feature_name_clean" | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1' FS='[-_]' OFS='')
    local widget_var_name 
    widget_var_name=$(echo "$feature_name_pascal" | awk '{print tolower(substr($0,1,1)) substr($0,2)}') 
    widget_var_name="${widget_var_name}Widget" 


    if [ -z "$file_prefix" ]; then echo "[ERROR] Widget name cannot be empty."; return; fi

    local file_name="${file_prefix}_widget.go"
    local target_file_path="${UI_WIDGETS_PATH}/${file_name}"

    echo "[INFO] Creating files for new widget: ${widget_name_input}"
    local widget_template_content; read -r -d '' widget_template_content << EOM_WIDGET
package widgets

import (
	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/widget"
	// "time" // Example for dynamic content
	// "fmt"  // Example for dynamic content
)

// ${feature_name_pascal}Widget is the Fyne component for your '${widget_name_input}' widget.
type ${feature_name_pascal}Widget struct {
	widget.BaseWidget
	label *widget.Label // Example: a simple label to display info
	// Add other Fyne components or fields your widget needs
}

// New${feature_name_pascal}Widget creates a new instance of your widget.
func New${feature_name_pascal}Widget(win fyne.Window, app fyne.App) *${feature_name_pascal}Widget {
	w := &${feature_name_pascal}Widget{}
	w.ExtendBaseWidget(w) // Essential for custom Fyne widgets

	// TODO: Initialize your widget's components here.
	// This is a placeholder.
	w.label = widget.NewLabel("Info from: ${widget_name_input} Widget")
	
	// Example: If your widget needs to update itself periodically
	// go w.startUpdating()

	return w
}

// CreateRenderer is a mandatory method for Fyne custom widgets.
// It defines how your widget should be drawn.
func (w *${feature_name_pascal}Widget) CreateRenderer() fyne.WidgetRenderer {
	// TODO: Arrange your widget's components in a Fyne container.
	// This is a placeholder.
	return widget.NewSimpleRenderer(container.NewPadded(w.label))
}

// Optional: Example of a function to update the widget's content
// func (w *${feature_name_pascal}Widget) startUpdating() {
//	 for {
//		 if w.label == nil || w.label.Hidden { // Stop if widget is no longer in use
//			 return
//		 }
//		 // TODO: Fetch or calculate new data for your widget
//		 newText := fmt.Sprintf("${widget_name_input} - Last updated: %s", time.Now().Format("15:04:05"))
//		 w.label.SetText(newText)
//		 w.Refresh() // Tell Fyne to redraw the widget
//		 time.Sleep(5 * time.Second) // Update interval
//	 }
// }
EOM_WIDGET
    create_go_file "$target_file_path" "widgets" "Fyne UI and logic for ${widget_name_input} widget." "${feature_name_pascal}" "$widget_template_content" "$current_module_name"

    if [ -f "$LAYOUT_FILE_PATH" ]; then
        echo "[INFO] Attempting to automatically add widget to '${LAYOUT_FILE_PATH}'..."
        
        WIDGETS_IMPORT_PATH="\"${current_module_name}/internal/ui/widgets\""
        if ! grep -qF "$WIDGETS_IMPORT_PATH" "$LAYOUT_FILE_PATH"; then
            sed -i.bak "/\/\/ AUTO_IMPORTS_START/a\\
	${WIDGETS_IMPORT_PATH}" "$LAYOUT_FILE_PATH" && rm "${LAYOUT_FILE_PATH}.bak"
            echo "[SUCCESS] Added import for 'widgets' package."
        else
            echo "[INFO] 'widgets' package import already present."
        fi

        INSTANTIATION_LINE="	${widget_var_name} := widgets.New${feature_name_pascal}Widget(win, app)"
        sed -i.bak "/\/\/ AUTO_WIDGET_INSTANTIATIONS_START/a\\
${INSTANTIATION_LINE}" "$LAYOUT_FILE_PATH" && rm "${LAYOUT_FILE_PATH}.bak"
        echo "[SUCCESS] Added widget creation line: ${widget_var_name}"

        LIST_ADDITION_LINE="		${widget_var_name},"
        sed -i.bak "/\/\/ AUTO_WIDGET_LIST_START/a\\
${LIST_ADDITION_LINE}" "$LAYOUT_FILE_PATH" && rm "${LAYOUT_FILE_PATH}.bak"
        echo "[SUCCESS] Added widget to the dashboard display list."
        echo "[ACTION REQUIRED] Widget auto-integration attempted. Please review '${LAYOUT_FILE_PATH}'."
        echo "                  Then run 'go mod tidy' and 'go run main.go' to see the changes."
    else
        echo "[WARNING] '${LAYOUT_FILE_PATH}' not found. Cannot auto-integrate widget. Please add it manually."
    fi
}

generate_service_feature() {
    local current_module_name="$1"
    echo ""
    read -r -p "Describe the new background task or data connection (e.g., Weather API, User Settings Saver): " service_name_input
    local file_prefix=$(echo "$service_name_input" | tr '[:upper:]' '[:lower:]' | tr ' -' '_')
    local feature_name_pascal=$(echo "$service_name_input" | sed 's/[^a-zA-Z0-9]//g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1' FS='[-_]' OFS='')

    if [ -z "$file_prefix" ]; then echo "[ERROR] Description cannot be empty."; return; fi

    local file_name="${file_prefix}_service.go"
    local target_file_path="${SERVICES_PATH}/${file_name}"

    echo "[INFO] Creating files for new background task/data connection: ${service_name_input}"
    local service_template_content; read -r -d '' service_template_content << EOM_SERVICE
package services

// import (
//	"${current_module_name}/internal/models" // If your service uses data models
//  "fmt"
//  "errors"
// )

// ${feature_name_pascal}Service provides methods for '${service_name_input}'.
type ${feature_name_pascal}Service interface {
	// Define the actions your service can perform.
	// For example:
	// PerformAction(data string) (string, error)
	// FetchData() (models.SomeModel, error)
}

// ${file_prefix}ServiceImpl is an implementation of ${feature_name_pascal}Service.
type ${file_prefix}ServiceImpl struct {
	// Add any dependencies here, like API keys, database connections, or other services.
	// apiKey string
}

// New${feature_name_pascal}Service creates a new instance of your service.
// Pass any required dependencies here.
func New${feature_name_pascal}Service(/* apiKey string */) ${feature_name_pascal}Service {
	return &${file_prefix}ServiceImpl{
		// apiKey: apiKey,
	}
}

// Example implementation of a service method:
// func (s *${file_prefix}ServiceImpl) PerformAction(data string) (string, error) {
//	 if data == "" {
//		 return "", errors.New("input data cannot be empty")
//	 }
//	 // TODO: Implement the actual logic for this action.
//	 result := fmt.Sprintf("Action performed on: %s", data)
//	 return result, nil
// }

// func (s *${file_prefix}ServiceImpl) FetchData() (models.SomeModel, error) {
//   // TODO: Implement data fetching logic
//   return models.SomeModel{Name: "Sample Data"}, nil
// }
EOM_SERVICE
    create_go_file "$target_file_path" "services" "Implements ${service_name_input} logic." "${feature_name_pascal}" "$service_template_content" "$current_module_name"
    echo "[INFO] Files for background task/data connection '${service_name_input}' created."
    echo "[ACTION REQUIRED] This is an advanced feature. You'll need to:"
    echo "                  1. Implement the actual logic in '${target_file_path}'."
    echo "                  2. Create an instance of this service in your application (e.g., in 'main.go' or a core setup file)."
    echo "                  3. Call its methods from your UI modules or other parts of your application where needed."
}

generate_data_model_feature() {
    local current_module_name="$1"
    echo ""
    read -r -p "What kind of information do you want to store/manage? (e.g., Customer, Project Task, Note): " model_name_input
    local file_name_base=$(echo "$model_name_input" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-zA-Z0-9_]//g')
    local feature_name_pascal=$(echo "$model_name_input" | sed 's/[^a-zA-Z0-9]//g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1' FS='[-_]' OFS='')

    if [ -z "$file_name_base" ]; then echo "[ERROR] Information type name cannot be empty or invalid."; return; fi
    local file_name="${file_name_base}_model.go" 
    local target_file_path="${MODELS_PATH}/${file_name}"

    echo "[INFO] Creating files for new information type: ${model_name_input}"
    local model_template_content; read -r -d '' model_template_content << EOM_MODEL
package models

// import "gorm.io/gorm" // Example if you plan to use GORM for database interaction

// ${feature_name_pascal} defines the structure for storing '${model_name_input}' information.
type ${feature_name_pascal} struct {
	// gorm.Model // Uncomment if using GORM (provides ID, CreatedAt, UpdatedAt, DeletedAt)
	
	// Example fields - replace these with the actual details you want to store.
	ID   uint   ` + "`json:\"id\" gorm:\"primaryKey\"`" + ` // A unique identifier
	Name string ` + "`json:\"name\"`" + `                 // A descriptive name or title
	
	// Add more fields below as needed for '${model_name_input}'. For example:
	// Description string    ` + "`json:\"description,omitempty\"`" + `
	// IsCompleted bool      ` + "`json:\"is_completed\"`" + `
	// DueDate     time.Time ` + "`json:\"due_date,omitempty\"`" + `
}
EOM_MODEL
    create_go_file "$target_file_path" "models" "Defines data structure for ${model_name_input}." "${feature_name_pascal}" "$model_template_content" "$current_module_name"
    echo "[INFO] Files for information type '${model_name_input}' created."
    echo "[ACTION REQUIRED] This is an advanced feature. You'll need to:"
    echo "                  1. Define the specific fields for '${model_name_input}' in '${target_file_path}'."
    echo "                  2. Use this data structure in your services or UI modules to manage this type of information."
    echo "                  3. If using a database, you might need to add this to your database setup/migrations."
}


# --- Main Script Logic ---
echo "What would you like to do?"
echo "  1. Create a new Fast Dashboard project"
echo "  2. Add features to an existing Fast Dashboard project"
echo "  0. Exit"
read -r -p "Enter your choice [0-2]: " main_choice

case $main_choice in
    1)
        generate_new_dashboard_project
        ;;
    2)
        add_feature_to_existing_project
        ;;
    0)
        echo "Exiting."
        ;;
    *)
        echo "[ERROR] Invalid choice. Exiting."
        ;;
esac

echo ""
echo "Unified Fast Dashboard Manager finished."


