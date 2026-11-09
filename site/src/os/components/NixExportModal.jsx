import { useState } from "react";
import { X, Copy, Check, Download } from "lucide-react";
import { generateNixConfig } from "@/lib/generateNixConfig";

export default function NixExportModal({ open, onClose, profile, options }) {
  const [copied, setCopied] = useState(false);

  if (!open || !profile) return null;

  const code = generateNixConfig(profile, options);

  const handleCopy = () => {
    navigator.clipboard.writeText(code);
    setCopied(true);
    setTimeout(() => setCopied(false), 1500);
  };

  const handleDownload = () => {
    const blob = new Blob([code], { type: "text/plain" });
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = `${profile.name}.nix`;
    a.click();
  };

  return (
    <div className="fixed inset-0 z-[60] flex items-center justify-center p-4 bg-black/60">
      <div className="bg-card border border-border w-full max-w-2xl flex flex-col max-h-[85vh]">
        <div className="flex items-center justify-between px-5 py-4 border-b border-border shrink-0">
          <div>
            <h2 className="font-mono text-sm font-semibold">
              export nix config
            </h2>
            <p className="text-xs text-muted-foreground mt-0.5 font-mono">
              {profile.name} · {profile.platform}
            </p>
          </div>
          <div className="flex items-center gap-2">
            <button
              onClick={handleDownload}
              className="flex items-center gap-1.5 px-3 py-1.5 text-xs border border-border text-muted-foreground hover:text-foreground transition-colors font-mono"
            >
              <Download className="w-3.5 h-3.5" /> .nix
            </button>
            <button
              onClick={handleCopy}
              className="flex items-center gap-1.5 px-3 py-1.5 text-xs bg-foreground text-background hover:bg-primary transition-colors font-mono"
            >
              {copied ? (
                <Check className="w-3.5 h-3.5" />
              ) : (
                <Copy className="w-3.5 h-3.5" />
              )}
              {copied ? "copied!" : "copy"}
            </button>
            <button
              onClick={onClose}
              className="ml-1 text-muted-foreground hover:text-foreground"
            >
              <X className="w-4 h-4" />
            </button>
          </div>
        </div>
        <div className="flex-1 overflow-auto">
          <pre className="terminal-block p-5 text-xs leading-relaxed h-full min-h-0 whitespace-pre overflow-x-auto">
            <code>{code}</code>
          </pre>
        </div>
      </div>
    </div>
  );
}
