#!/bin/bash

# Generate GTK theme from pywal colors
source "$HOME/.cache/wal/colors.sh"

# Create GTK-3.0 directory
mkdir -p ~/.config/gtk-3.0

# Generate comprehensive GTK CSS with pywal colors
cat > ~/.config/gtk-3.0/gtk.css << EOF
/* Pywal GTK Theme - Auto-generated */

/* Import base colors */
@define-color theme_fg_color ${foreground};
@define-color theme_text_color ${foreground};
@define-color theme_bg_color ${background};
@define-color theme_base_color ${color0};
@define-color theme_selected_bg_color ${color1};
@define-color theme_selected_fg_color ${background};
@define-color insensitive_fg_color ${color8};
@define-color borders ${color8};

/* Base widgets */
* {
    background-color: ${background};
    color: ${foreground};
}

.background {
    background-color: ${background};
    color: ${foreground};
}

/* Windows and views */
window {
    background-color: ${background};
    color: ${foreground};
}

.view,
textview text,
iconview,
.content-view {
    background-color: ${color0};
    color: ${foreground};
}

.view:selected,
textview text:selected,
iconview:selected,
.content-view:selected {
    background-color: ${color1};
    color: ${background};
}

/* Headers and titlebars */
headerbar,
.titlebar {
    background-color: ${color0};
    color: ${foreground};
}

headerbar:backdrop,
.titlebar:backdrop {
    background-color: ${color0};
    color: ${color8};
}

/* Menubars */
menubar,
.menubar {
    background-color: ${color0};
    color: ${foreground};
}

menubar > menuitem,
.menubar > menuitem {
    background-color: ${color0};
    color: ${foreground};
}

menubar > menuitem:hover,
.menubar > menuitem:hover {
    background-color: ${color1};
    color: ${background};
}

/* Menus and popovers */
menu,
.menu,
.context-menu,
popover,
popover.background {
    background-color: ${color0};
    color: ${foreground};
    border: 1px solid ${color8};
}

menuitem,
menu menuitem,
.menu menuitem {
    background-color: ${color0};
    color: ${foreground};
}

menuitem:hover,
menu menuitem:hover,
.menu menuitem:hover {
    background-color: ${color1};
    color: ${background};
}

/* Buttons */
button {
    background-color: ${color0};
    color: ${foreground};
    border: 1px solid ${color8};
}

button:hover {
    background-color: ${color1};
    color: ${background};
}

button:active,
button:checked {
    background-color: ${color1};
    color: ${background};
}

button:disabled {
    background-color: ${color0};
    color: ${color8};
}

button.flat {
    background-color: transparent;
    border: none;
}

/* Entry fields */
entry {
    background-color: ${color0};
    color: ${foreground};
    border: 1px solid ${color8};
}

entry:focus {
    background-color: ${color0};
    color: ${foreground};
    border: 1px solid ${color1};
}

entry:disabled {
    background-color: ${color0};
    color: ${color8};
}

entry selection {
    background-color: ${color1};
    color: ${background};
}

/* Notebooks and tabs */
notebook,
notebook > header {
    background-color: ${background};
}

notebook > header > tabs > tab {
    background-color: ${color0};
    color: ${foreground};
}

notebook > header > tabs > tab:checked {
    background-color: ${color1};
    color: ${background};
}

notebook > stack {
    background-color: ${color0};
}

/* Sidebars */
.sidebar,
sidebar,
stacksidebar {
    background-color: ${color0};
    color: ${foreground};
}

.sidebar row,
sidebar row,
stacksidebar row {
    background-color: ${color0};
    color: ${foreground};
}

.sidebar row:selected,
sidebar row:selected,
stacksidebar row:selected {
    background-color: ${color1};
    color: ${background};
}

/* Lists and rows */
list,
listview,
row {
    background-color: ${color0};
    color: ${foreground};
}

list row:hover,
listview row:hover,
row:hover {
    background-color: ${color1};
    color: ${background};
}

list row:selected,
listview row:selected,
row:selected {
    background-color: ${color1};
    color: ${background};
}

/* Tree views */
treeview,
treeview.view {
    background-color: ${color0};
    color: ${foreground};
}

treeview.view header button,
treeview header button {
    background-color: ${color0};
    color: ${foreground};
    border: 1px solid ${color8};
}

treeview:selected,
treeview.view:selected {
    background-color: ${color1};
    color: ${background};
}

/* Scrollbars */
scrollbar,
scrollbar slider {
    background-color: ${color0};
}

scrollbar slider:hover {
    background-color: ${color1};
}

/* Toolbars */
toolbar {
    background-color: ${color0};
    color: ${foreground};
}

/* Pathbars and location bars */
.path-bar,
.location-bar,
pathbar {
    background-color: ${color0};
    color: ${foreground};
}

.path-bar button,
pathbar button {
    background-color: ${color0};
    color: ${foreground};
}

.path-bar button:checked,
pathbar button:checked {
    background-color: ${color1};
    color: ${background};
}

/* Frames */
frame,
frame > border {
    background-color: ${color0};
    border: 1px solid ${color8};
}

/* Scrolled windows */
scrolledwindow,
scrolledwindow viewport {
    background-color: ${color0};
}

/* Separators */
separator {
    background-color: ${color8};
    color: ${color8};
}

/* Paned widgets */
paned > separator {
    background-color: ${color8};
}

/* Scales and progress bars */
scale trough,
progressbar trough {
    background-color: ${color8};
}

scale highlight,
progressbar progress {
    background-color: ${color1};
}

/* Checkboxes and radio buttons */
check,
radio {
    background-color: ${color0};
    color: ${foreground};
}

check:checked,
radio:checked {
    background-color: ${color1};
    color: ${background};
}

/* Switches */
switch {
    background-color: ${color8};
}

switch:checked {
    background-color: ${color1};
}

switch slider {
    background-color: ${color0};
}

/* Tooltips */
tooltip,
tooltip.background {
    background-color: ${color0};
    color: ${foreground};
    border: 1px solid ${color8};
}

/* Calendars */
calendar {
    background-color: ${color0};
    color: ${foreground};
}

calendar:selected {
    background-color: ${color1};
    color: ${background};
}

/* EVOLUTION-SPECIFIC FIXES */

/* Evolution main window */
.evolution-mail-view {
    background-color: ${color0};
}

/* Message list (where emails are listed) */
.message-list,
.message-list treeview,
.message-list treeview.view {
    background-color: ${color0};
    color: ${foreground};
}

.message-list treeview:selected,
.message-list treeview.view:selected {
    background-color: ${color1};
    color: ${background};
}

/* Email preview pane */
.mail-preview,
webview,
.webkit {
    background-color: ${color0};
    color: ${foreground};
}

/* Evolution sidebars and folder list */
.folder-tree,
.mail-sidebar {
    background-color: ${color0};
    color: ${foreground};
}

/* Task and calendar views */
.task-list,
.calendar-view {
    background-color: ${color0};
    color: ${foreground};
}

/* Contact list */
.contact-list,
.addressbook-view {
    background-color: ${color0};
    color: ${foreground};
}

/* APP-SPECIFIC OVERRIDES */

/* Pavucontrol */
#volume-scales,
#input-devices,
#output-devices {
    background-color: ${color0};
}

/* Nautilus/Nemo file managers */
.nautilus-window .sidebar,
.nemo-window .sidebar {
    background-color: ${color0};
}

.nautilus-canvas-item,
.nemo-icon-view {
    background-color: ${color0};
}

/* Gedit/Text editors */
.gedit-document-panel {
    background-color: ${color0};
}

/* GTK4 specific */
windowhandle,
splitview,
preferencesgroup {
    background-color: ${color0};
}

/* Ensure text is readable on colored backgrounds */
.view text,
textview text,
.view label,
textview label {
    color: ${foreground};
}

EOF

# Create GTK-4.0 directory and copy theme
mkdir -p ~/.config/gtk-4.0
cp ~/.config/gtk-3.0/gtk.css ~/.config/gtk-4.0/gtk.css

echo "GTK theme generated successfully!"