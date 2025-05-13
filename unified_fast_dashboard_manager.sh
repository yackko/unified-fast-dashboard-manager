#!/bin/bash

# This script serves as a unified manager for Fast Dashboard projects.
# It can:
# 1. Generate a new Fast Dashboard Go Fyne project boilerplate with user-defined window size, theme, and layout.
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
THEME_FILE_PATH="internal/theme/custom_theme.go" # For custom themes
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
        if [ -z "$feature_name_pascal_case" ];
        then
            feature_name_pascal_case=$(echo "$package_name" | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1' FS='[-_]' OFS='')
        fi

        if [ -n "$specific_template_content" ]; then
            printf "%s" "$specific_template_content" > "$file_path"
        else
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

type ${feature_name_pascal_case} struct {
	widget.BaseWidget
	label *widget.Label
}

func New${feature_name_pascal_case}(win fyne.Window, app fyne.App) *${feature_name_pascal_case} {
	s := &${feature_name_pascal_case}{}
	s.ExtendBaseWidget(s)
	s.label = widget.NewLabel("Hello from ${feature_name_pascal_case} (Sample Widget)!")
	return s
}

func (s *${feature_name_pascal_case}) CreateRenderer() fyne.WidgetRenderer {
	return widget.NewSimpleRenderer(container.NewCenter(s.label))
}

// TODO: Implement more specific logic for this feature.
EOL
        fi
        if [ $? -eq 0 ]; then echo "[SUCCESS] Created Go file: ${file_path}"; else echo "[ERROR] Failed to create Go file: ${file_path}"; fi
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
        echo "[WARNING] Could not robustly determine absolute path of the running script. Using '$0'. Self-copy might be affected."
    fi

    read -r -p "Enter project name (e.g., my-dashboard): " PROJECT_NAME_INPUT
    if [ -z "$PROJECT_NAME_INPUT" ]; then echo "[ERROR] Project name cannot be empty."; return; fi

    if [ -d "$PROJECT_NAME_INPUT" ]; then
        read -r -p "[WARNING] Directory '$PROJECT_NAME_INPUT' already exists. Overwrite? (yes/no): " OVERWRITE_CHOICE
        if [[ "$OVERWRITE_CHOICE" != "yes" ]]; then echo "Project creation cancelled."; return; fi
        rm -rf "$PROJECT_NAME_INPUT"
    fi

    mkdir "$PROJECT_NAME_INPUT"
    local ORIGINAL_PROJECT_NAME="$PROJECT_NAME_INPUT"
    cd "$PROJECT_NAME_INPUT" || { echo "[ERROR] Failed to cd into $PROJECT_NAME_INPUT."; return; }

    local SANITIZED_PROJECT_NAME=$(echo "$PROJECT_NAME_INPUT" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]' | sed 's/[^a-zA-Z0-9._-]//g')
    if [ -z "$SANITIZED_PROJECT_NAME" ]; then echo "[ERROR] Sanitized project name is empty."; cd ..; return; fi
    local MODULE_NAME="$SANITIZED_PROJECT_NAME"

    # --- Get Window Size ---
    local user_window_width user_window_height
    local default_width="1024" default_height="768"
    echo ""
    echo "--- Initial Window Size ---"
    read -r -p "Enter initial window width (default: ${default_width}): " user_window_width
    user_window_width=${user_window_width:-$default_width} 
    if ! [[ "$user_window_width" =~ ^[0-9]+$ ]] || [ "$user_window_width" -le 0 ]; then user_window_width=$default_width; fi
    read -r -p "Enter initial window height (default: ${default_height}): " user_window_height
    user_window_height=${user_window_height:-$default_height} 
    if ! [[ "$user_window_height" =~ ^[0-9]+$ ]] || [ "$user_window_height" -le 0 ]; then user_window_height=$default_height; fi
    echo "[INFO] Initial window size: ${user_window_width}x${user_window_height}"

    # --- Get Background Theme Choice ---
    local app_theme_choice app_theme_import app_theme_set_line custom_theme_needed="false"
    echo ""
    echo "--- Application Theme ---"
    echo "Select a base theme/background color:"
    echo "  1. Light (Fyne default)"
    echo "  2. Dark (Fyne default)"
    echo "  3. Custom Light Blueish (Background: #E0E8F0)"
    echo "  4. Custom Dark Grey (Background: #2E2E2E)"
    read -r -p "Enter theme choice [1-4] (default: 1): " theme_input
    theme_input=${theme_input:-1}

    case $theme_input in
        2) app_theme_choice="dark"; app_theme_import="fyne.io/fyne/v2/theme"; app_theme_set_line='myApp.Settings().SetTheme(theme.DarkTheme())';;
        3) app_theme_choice="custom_light_blue"; custom_theme_needed="true";;
        4) app_theme_choice="custom_dark_grey"; custom_theme_needed="true";;
        *) app_theme_choice="light"; app_theme_import="fyne.io/fyne/v2/theme"; app_theme_set_line='// myApp.Settings().SetTheme(theme.LightTheme()) // Default';;
    esac
    if [ "$custom_theme_needed" == "true" ]; then
        app_theme_import="${MODULE_NAME}/internal/theme" 
        app_theme_set_line='myApp.Settings().SetTheme(customtheme.NewCustomTheme())'
    fi
    echo "[INFO] Selected theme: ${app_theme_choice}"

    # --- Get Layout Choice ---
    local layout_choice_val="simple" 
    echo ""
    echo "--- Main Dashboard Layout ---"
    echo "Select a layout for the main dashboard area:"
    echo "  1. Simple Vertical List (widgets stacked top to bottom)"
    echo "  2. Tabbed View (widgets in a 'Dashboard' tab, space for other tabs)"
    echo "  3. Grid View (widgets arranged in a 2-column grid)"
    read -r -p "Enter layout choice [1-3] (default: 1): " layout_input
    layout_input=${layout_input:-1}
    case $layout_input in
        2) layout_choice_val="tabs";;
        3) layout_choice_val="grid";;
        *) layout_choice_val="simple";;
    esac
    echo "[INFO] Selected layout: ${layout_choice_val}"
    echo ""

    echo "[INFO] Creating core directories..."
    DIRECTORIES=("cli" "core" "generators" "templates" "utils" "internal/ui/layout" "internal/ui/widgets" "internal/ui/modules" "internal/config" "internal/services" "internal/models" "internal/theme")
    for dir in "${DIRECTORIES[@]}"; do mkdir -p "$dir"; echo "[SUCCESS] Created directory: $dir"; done

    echo "[INFO] Creating go.mod with module name: ${MODULE_NAME}"
    cat <<EOL_GOMOD > go.mod
module ${MODULE_NAME}

go 1.21

require fyne.io/fyne/v2 v2.4.0 
EOL_GOMOD
    echo "[SUCCESS] Created go.mod"

    echo "[INFO] Creating main.go..."
    local main_go_theme_import_line=""
    if [ -n "$app_theme_import" ]; then
      main_go_theme_import_line="	\"${app_theme_import}\""
    fi

    cat <<EOL_MAIN > main.go
package main

import (
	"${MODULE_NAME}/internal/ui/layout" 
${main_go_theme_import_line}
	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/app"
)

const (
	AppID      = "com.example.${MODULE_NAME}" 
	AppName    = "${ORIGINAL_PROJECT_NAME} Dashboard"
	WindowWidth  float32 = ${user_window_width}
	WindowHeight float32 = ${user_window_height}
)

func main() {
	myApp := app.NewWithID(AppID)
	${app_theme_set_line}

	myWindow := myApp.NewWindow(AppName)
	mainLayoutContent := layout.NewMainAppLayout(myWindow, myApp, "${layout_choice_val}") 

	myWindow.SetContent(mainLayoutContent)
	myWindow.Resize(fyne.NewSize(WindowWidth, WindowHeight))
	myWindow.SetMaster()
	myWindow.ShowAndRun()
}
EOL_MAIN
    echo "[SUCCESS] Created main.go."

    if [ "$custom_theme_needed" == "true" ]; then
        echo "[INFO] Creating custom theme file: ${THEME_FILE_PATH}"
        local bg_color_hex
        if [ "$app_theme_choice" == "custom_light_blue" ]; then
            bg_color_hex="#E0E8F0" 
        elif [ "$app_theme_choice" == "custom_dark_grey" ]; then
            bg_color_hex="#2E2E2E" 
        fi
        
        cat <<EOL_THEME > "${THEME_FILE_PATH}"
package customtheme

import (
	"fmt" 
	"image/color"
	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/theme"
)

type myTheme struct {
	fyne.Theme
	customBgColor color.Color
}

func (m *myTheme) Color(name fyne.ThemeColorName, variant fyne.ThemeVariant) color.Color {
	if name == theme.ColorNameBackground {
		return m.customBgColor
	}
	if variant == theme.VariantDark && m.isDarkColor(m.customBgColor) {
		if name == theme.ColorNameForeground || name == theme.ColorNamePlaceHolder || name == theme.ColorNamePrimary || name == theme.ColorNameButton {
			return color.NRGBA{R: 0xE0, G: 0xE0, B: 0xE0, A: 0xFF} 
		}
        if name == theme.ColorNameDisabled {
             return color.NRGBA{R:0x77, G:0x77, B:0x77, A:0xff} 
        }
	}
    if variant == theme.VariantLight && !m.isDarkColor(m.customBgColor) {
        if name == theme.ColorNameForeground || name == theme.ColorNamePlaceHolder {
             return color.NRGBA{R:0x20, G:0x20, B:0x20, A:0xff} 
        }
    }
	return m.Theme.Color(name, variant)
}

func (m *myTheme) Icon(name fyne.ThemeIconName) fyne.Resource {
	if m.isDarkColor(m.customBgColor) && (name == theme.IconNameCancel || name == theme.IconNameConfirm || name == theme.IconNameDelete || name == theme.IconNameSearch || name == theme.IconNameMenu) {
	}
	return m.Theme.Icon(name)
}

func (m *myTheme) isDarkColor(c color.Color) bool {
    r, g, b, _ := c.RGBA()
    luminance := (0.299*float64(r>>8) + 0.587*float64(g>>8) + 0.114*float64(b>>8))
    return luminance < 128 
}

func NewCustomTheme() fyne.Theme {
	bgR, bgG, bgB := parseHexColor("${bg_color_hex}")
	base := theme.DefaultTheme() 
    if (0.299*float64(bgR) + 0.587*float64(bgG) + 0.114*float64(bgB)) < 128 {
        base = theme.DarkTheme()
    } else {
        base = theme.LightTheme()
    }
	return &myTheme{
		Theme: base,
		customBgColor: color.NRGBA{R: uint8(bgR), G: uint8(bgG), B: uint8(bgB), A: 0xff},
	}
}

func parseHexColor(s string) (r, g, b uint8) {
	s = s[1:] 
	if len(s) == 6 {
		fmt.Sscanf(s, "%02x%02x%02x", &r, &g, &b)
	}
	return
}
EOL_THEME
        echo "[SUCCESS] Created custom theme: ${THEME_FILE_PATH}"
    fi

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

    echo "[INFO] Creating internal/ui/layout/main_layout.go with selected layout and initial sample widget..."
    # Corrected main_layout.go template
    cat <<EOL_LAYOUT > "${LAYOUT_FILE_PATH}"
package layout

import (
	"fmt"
	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/widget"
	"fyne.io/fyne/v2/theme"
	// This ${MODULE_NAME} will be replaced by your actual module name by the script
	// e.g., "rabbit-hole/internal/ui/widgets"
	"${MODULE_NAME}/internal/ui/widgets" 
	// AUTO_IMPORTS_START 
	// (This line is a hook for the script, do not remove)
	// AUTO_IMPORTS_END 
	// (This line is a hook for the script, do not remove)
)

// NewMainAppLayout creates the overall application layout.
// layoutType can be "simple", "tabs", or "grid".
func NewMainAppLayout(win fyne.Window, app fyne.App, layoutType string) fyne.CanvasObject {
	
	// This ${ORIGINAL_PROJECT_NAME} will be replaced by your actual project name
	pageTitle := widget.NewLabel("Welcome to ${ORIGINAL_PROJECT_NAME}!")
	pageTitle.Alignment = fyne.TextAlignCenter

	sampleWidgetInstance := widgets.NewSample(win, app) // Assumes NewSample is in widgets package

	// AUTO_WIDGET_INSTANTIATIONS_START 
	// (This line is a hook for the script, do not remove)
	// AUTO_WIDGET_INSTANTIATIONS_END 
	// (This line is a hook for the script, do not remove)

	dashboardWidgets := []fyne.CanvasObject{
		sampleWidgetInstance, // Initial sample widget
		// AUTO_WIDGET_LIST_START 
		// (This line is a hook for the script, do not remove)
		// AUTO_WIDGET_LIST_END 
		// (This line is a hook for the script, do not remove)
	}

	var finalDashboardArea fyne.CanvasObject
	var activeWidgetsContainer *fyne.Container // Declare a single container for widgets

	if layoutType == "grid" {
		activeWidgetsContainer = container.NewGridWithColumns(2) // CORRECTED: Was NewGridLayout
	} else { // "simple" or "tabs" (tabs will use a VBox for its tab content)
		activeWidgetsContainer = container.NewVBox()
	}

	for _, w := range dashboardWidgets {
		if w != nil {
			activeWidgetsContainer.Add(w)
            // Add separator for simple and tabs layout, but not for grid.
            if layoutType != "grid" {
                 activeWidgetsContainer.Add(widget.NewSeparator())
            }
		}
	}

	if layoutType == "tabs" {
		// For tabs, the activeWidgetsContainer (which is a VBox) becomes the content of the "Dashboard" tab.
		finalDashboardArea = container.NewAppTabs(
			container.NewTabItem("Dashboard", container.NewScroll(activeWidgetsContainer)),
			// Example: You can add more TabItems here for different modules/pages
			// container.NewTabItem("Settings", widget.NewLabel("Settings Content Here - TODO")),
		)
	} else { // "simple" or "grid"
		finalDashboardArea = container.NewScroll(activeWidgetsContainer)
	}
    
    var topContentItems []fyne.CanvasObject
    topContentItems = append(topContentItems, pageTitle)
    topContentItems = append(topContentItems, widget.NewSeparator())
    topContentItems = append(topContentItems, widget.NewLabelWithStyle("Dashboard Area:", fyne.TextAlignLeading, fyne.TextStyle{Bold: true}))

	// mainDisplayArea combines title, separator, label, and then the finalDashboardArea (which is scrollable)
	mainDisplayArea := container.NewVBox(append(topContentItems, finalDashboardArea)...)


	toolbar := widget.NewToolbar(
		widget.NewToolbarAction(theme.HomeIcon(), func() { fmt.Println("Home action for ${ORIGINAL_PROJECT_NAME}") }),
		widget.NewToolbarSeparator(),
		widget.NewToolbarAction(theme.SettingsIcon(), func() { 
            // Example: Show a dialog or trigger navigation to a settings module
            dialog := widget.NewModalPopUp(widget.NewLabel("Settings Clicked! Implement navigation to a settings module here."), win.Canvas())
            dialog.Show()
            // To hide after a delay (example):
            // time.AfterFunc(3*time.Second, func() { dialog.Hide() })
        }),
	)

	return container.NewBorder(toolbar, nil, nil, nil, mainDisplayArea)
}
EOL_LAYOUT
    echo "[SUCCESS] Created ${LAYOUT_FILE_PATH} with selected layout and initial sample widget."

    if [ -n "$current_script_abs_path" ] && [ -f "$current_script_abs_path" ]; then
        cp "$current_script_abs_path" "./${SCRIPT_NAME_IN_PROJECT}"
        chmod +x "./${SCRIPT_NAME_IN_PROJECT}"
        echo "[SUCCESS] Copied management script to './${SCRIPT_NAME_IN_PROJECT}'"
    else
        echo "[WARNING] Could not copy management script. Please copy it manually if needed."
    fi

    echo ""
    echo "----------------------------------------------------"
    echo "Fast Dashboard project '${ORIGINAL_PROJECT_NAME}' created successfully!"
    echo "Module name: '${MODULE_NAME}', Theme: '${app_theme_choice}', Layout: '${layout_choice_val}'"
    echo "----------------------------------------------------"
    echo "Next steps:"
    echo "1. cd \"${ORIGINAL_PROJECT_NAME}\""
    echo "2. go mod tidy"
    echo "3. go run main.go"
    echo "4. To add features later, run './${SCRIPT_NAME_IN_PROJECT}' from within the project directory."
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
        echo "[ERROR] Could not proceed. Ensure you are in a project root with a valid go.mod."
        return
    fi
    echo "[INFO] Current project module: ${CURRENT_MODULE_NAME_FOR_ADD}"

    mkdir -p "$UI_MODULES_PATH" "$UI_WIDGETS_PATH" "$SERVICES_PATH" "$MODELS_PATH"

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
    read -r -p "What do you want to call this new page/section? (e.g., User Profile): " module_name_input
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

func New${feature_name_pascal}View(win fyne.Window, app fyne.App) fyne.CanvasObject {
	return container.NewCenter(widget.NewLabel("Content for '${module_name_input}' Page/Section"))
}
EOM_VIEW
    create_go_file "${target_dir}/view.go" "${package_name}" "Fyne UI view for ${module_name_input}." "${feature_name_pascal}" "$view_template_content" "$current_module_name"
    
    local logic_template_content; read -r -d '' logic_template_content << EOM_LOGIC
package ${package_name}
EOM_LOGIC
    create_go_file "${target_dir}/logic.go" "${package_name}" "Business logic for ${module_name_input}." "${feature_name_pascal}" "$logic_template_content" "$current_module_name"
    
    echo "[INFO] Files for page/section '${module_name_input}' created."
    echo "[ACTION REQUIRED] Manual integration needed: Add navigation to this module in '${LAYOUT_FILE_PATH}'."
    echo "                  If using 'tabs' layout, you can add a new TabItem in NewMainAppLayout."
    echo "                  Otherwise, add a button and logic to switch the main content area."
}

generate_dashboard_widget_feature() {
    local current_module_name="$1"
    echo ""
    read -r -p "What do you want to call this new widget/info box? (e.g., My Clock): " widget_name_input
    local file_prefix=$(echo "$widget_name_input" | tr '[:upper:]' '[:lower:]' | tr ' -' '_')
    local feature_name_clean=$(echo "$widget_name_input" | sed 's/[^a-zA-Z0-9]//g')
    local feature_name_pascal=$(echo "$feature_name_clean" | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1' FS='[-_]' OFS='')
    local widget_var_name=$(echo "$feature_name_pascal" | awk '{print tolower(substr($0,1,1)) substr($0,2)}')Widget

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
)

type ${feature_name_pascal}Widget struct {
	widget.BaseWidget
	label *widget.Label
}

func New${feature_name_pascal}Widget(win fyne.Window, app fyne.App) *${feature_name_pascal}Widget {
	w := &${feature_name_pascal}Widget{}
	w.ExtendBaseWidget(w)
	w.label = widget.NewLabel("Info from: ${widget_name_input} Widget")
	return w
}

func (w *${feature_name_pascal}Widget) CreateRenderer() fyne.WidgetRenderer {
	return widget.NewSimpleRenderer(container.NewPadded(w.label))
}
EOM_WIDGET
    create_go_file "$target_file_path" "widgets" "Fyne UI for ${widget_name_input} widget." "${feature_name_pascal}" "$widget_template_content" "$current_module_name"

    if [ -f "$LAYOUT_FILE_PATH" ]; then
        echo "[INFO] Attempting to auto-integrate widget into '${LAYOUT_FILE_PATH}'..."
        WIDGETS_IMPORT_PATH="\"${current_module_name}/internal/ui/widgets\""
        if ! grep -qF "$WIDGETS_IMPORT_PATH" "$LAYOUT_FILE_PATH"; then
            sed -i.bak "/\/\/ AUTO_IMPORTS_START/a\\
	${WIDGETS_IMPORT_PATH}" "$LAYOUT_FILE_PATH" && rm "${LAYOUT_FILE_PATH}.bak"
            echo "[SUCCESS] Added import for 'widgets' package."
        fi
        INSTANTIATION_LINE="	${widget_var_name} := widgets.New${feature_name_pascal}Widget(win, app)"
        sed -i.bak "/\/\/ AUTO_WIDGET_INSTANTIATIONS_START/a\\
${INSTANTIATION_LINE}" "$LAYOUT_FILE_PATH" && rm "${LAYOUT_FILE_PATH}.bak"
        LIST_ADDITION_LINE="		${widget_var_name},"
        sed -i.bak "/\/\/ AUTO_WIDGET_LIST_START/a\\
${LIST_ADDITION_LINE}" "$LAYOUT_FILE_PATH" && rm "${LAYOUT_FILE_PATH}.bak"
        echo "[SUCCESS] Widget auto-integration hooks updated in '${LAYOUT_FILE_PATH}'."
        echo "[ACTION REQUIRED] Review '${LAYOUT_FILE_PATH}', run 'go mod tidy' & 'go run main.go'."
    else
        echo "[WARNING] '${LAYOUT_FILE_PATH}' not found. Cannot auto-integrate widget."
    fi
}

generate_service_feature() {
    local current_module_name="$1"
    echo ""
    read -r -p "Describe the new background task or data connection: " service_name_input
    local file_prefix=$(echo "$service_name_input" | tr '[:upper:]' '[:lower:]' | tr ' -' '_')
    local feature_name_pascal=$(echo "$service_name_input" | sed 's/[^a-zA-Z0-9]//g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1' FS='[-_]' OFS='')
    if [ -z "$file_prefix" ]; then echo "[ERROR] Description cannot be empty."; return; fi
    local file_name="${file_prefix}_service.go"; local target_file_path="${SERVICES_PATH}/${file_name}"
    echo "[INFO] Creating files for service: ${service_name_input}"
    local service_template_content; read -r -d '' service_template_content << EOM_SERVICE
package services
type ${feature_name_pascal}Service interface {}
type ${file_prefix}ServiceImpl struct {}
func New${feature_name_pascal}Service() ${feature_name_pascal}Service { return &${file_prefix}ServiceImpl{} }
EOM_SERVICE
    create_go_file "$target_file_path" "services" "Implements ${service_name_input} logic." "${feature_name_pascal}" "$service_template_content" "$current_module_name"
    echo "[INFO] Service '${service_name_input}' files created. Implement logic and integrate manually."
}

generate_data_model_feature() {
    local current_module_name="$1"
    echo ""
    read -r -p "What kind of information to store/manage?: " model_name_input
    local file_name_base=$(echo "$model_name_input" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-zA-Z0-9_]//g')
    local feature_name_pascal=$(echo "$model_name_input" | sed 's/[^a-zA-Z0-9]//g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1' FS='[-_]' OFS='')
    if [ -z "$file_name_base" ]; then echo "[ERROR] Name cannot be empty."; return; fi
    local file_name="${file_name_base}_model.go"; local target_file_path="${MODELS_PATH}/${file_name}"
    echo "[INFO] Creating files for model: ${model_name_input}"
    local model_template_content; read -r -d '' model_template_content << EOM_MODEL
package models
type ${feature_name_pascal} struct {
	ID   uint   ` + "`json:\"id\" gorm:\"primaryKey\"`" + `
	Name string ` + "`json:\"name\"`" + `
}
EOM_MODEL
    create_go_file "$target_file_path" "models" "Defines data structure for ${model_name_input}." "${feature_name_pascal}" "$model_template_content" "$current_module_name"
    echo "[INFO] Model '${model_name_input}' files created. Define fields and integrate manually."
}

# --- Main Script Logic ---
echo "What would you like to do?"
echo "  1. Create a new Fast Dashboard project"
echo "  2. Add features to an existing Fast Dashboard project"
echo "  0. Exit"
read -r -p "Enter your choice [0-2]: " main_choice

case $main_choice in
    1) generate_new_dashboard_project ;;
    2) add_feature_to_existing_project ;;
    0) echo "Exiting." ;;
    *) echo "[ERROR] Invalid choice. Exiting." ;;
esac

echo ""
echo "Unified Fast Dashboard Manager finished."
