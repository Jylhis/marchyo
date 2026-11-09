let
  app = name: url: {
    inherit name url;
    icon = null;
    key = null;
  };
in
{
  m365 = [
    (app "Outlook" "https://outlook.office.com/mail/")
    (app "Word" "https://word.cloud.microsoft/")
    (app "Excel" "https://excel.cloud.microsoft/")
    (app "PowerPoint" "https://powerpoint.cloud.microsoft/")
    (app "Teams" "https://teams.cloud.microsoft/")
    (app "OneDrive" "https://www.office.com/launch/onedrive")
  ];

  google = [
    (app "Gmail" "https://mail.google.com/")
    (app "Google Calendar" "https://calendar.google.com/")
    (app "Google Drive" "https://drive.google.com/")
    (app "Google Docs" "https://docs.google.com/document/")
    (app "Google Sheets" "https://docs.google.com/spreadsheets/")
    (app "Google Slides" "https://docs.google.com/presentation/")
    (app "Google Meet" "https://meet.google.com/")
    (app "Google Chat" "https://chat.google.com/")
    (app "Google Keep" "https://keep.google.com/")
    (app "Google Forms" "https://docs.google.com/forms/")
    (app "Google Sites" "https://sites.google.com/")
    (app "Google Contacts" "https://contacts.google.com/")
    (app "Google Tasks" "https://tasks.google.com/")
  ];

  notion = app "Notion" "https://www.notion.so/";
}
