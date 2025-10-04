{
  programs.wofi = {
    enable = true;
    settings = {
      width = 600;
      height = 350;
      location = "center";
      show = "drun";
      prompt = "Search...";
      filter_rate = 100;
      allow_markup = true;
      no_actions = true;
      halign = "fill";
      orientation = "vertical";
      content_halign = "fill";
      insensitive = true;
      allow_images = true;
      image_size = 40;
      gtk_dark = true;
    };
    style = ''
      * {
         font-family: 'CaskaydiaMono Nerd Font', monospace;
         font-size: 18px;
       }

       window {
         margin: 0px;
         padding: 20px;        
         opacity: 0.95;
       }

       #inner-box {
         margin: 0;
         padding: 0;
         border: none;
       }

       #outer-box {
         margin: 0;
         padding: 20px;
         border: none;
       }

       #scroll {
         margin: 0;
         padding: 0;
         border: none;
       }

       #input {
         margin: 0;
         padding: 10px;
         border: none;
         color: @text;
       }

       #input:focus {
         outline: none;
         box-shadow: none;
         border: none;
       }

       #text {
         margin: 5px;
         border: none;
       }

       #entry:selected {
         outline: none;
         border: none;
       }

       #entry image {
         -gtk-icon-transform: scale(0.7);
       }
    '';
  };
}
