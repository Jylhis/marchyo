{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.marchyo.xournalpp = {
    enable = lib.mkEnableOption "Xournal++ note-taking application" // {
      default = true;
    };
  };

  config = lib.mkIf config.marchyo.xournalpp.enable {
    home.packages = [ pkgs.xournalpp ];

    # Xournal++ configuration
    xdg.configFile."xournalpp/settings.xml".text = ''
      <?xml version="1.0" encoding="UTF-8"?>
      <settings dark="forceDark" iconTheme="iconsColor">
        <property name="presureSensitivity" value="true"/>
        <property name="minimumPressure" value="0.05"/>
        <property name="zoomGesturesEnabled" value="true"/>
        <property name="selectedToolbar" value="Portrait"/>
        <property name="showSidebar" value="true"/>
        <property name="sidebarWidth" value="150"/>

        <!-- Autosave settings -->
        <property name="autosaveEnabled" value="true"/>
        <property name="autosaveTimeout" value="3"/>

        <!-- Default save names -->
        <property name="defaultSaveName" value="%F-Note-%H-%M"/>
        <property name="defaultPdfExportName" value="%{name}_annotated"/>

        <!-- Snap settings -->
        <property name="snapRotation" value="true"/>
        <property name="snapRotationTolerance" value="0.3"/>
        <property name="snapGrid" value="true"/>
        <property name="snapGridSize" value="14.17"/>

        <!-- Stylus and eraser -->
        <property name="stylusCursorType" value="dot"/>
        <property name="eraserVisibility" value="always"/>

        <!-- PDF settings -->
        <property name="pdfPageCacheSize" value="10"/>
        <property name="preloadPagesBefore" value="3"/>
        <property name="preloadPagesAfter" value="5"/>

        <!-- Main window -->
        <property name="maximized" value="true"/>
        <property name="windowWidth" value="800"/>
        <property name="windowHeight" value="600"/>
      </settings>
    '';
  };
}
