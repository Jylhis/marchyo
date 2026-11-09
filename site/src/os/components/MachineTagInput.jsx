import { useState } from "react";
import { X } from "lucide-react";

export default function MachineTagInput({ tags, onChange }) {
  const [input, setInput] = useState("");

  const add = () => {
    const val = input.trim().toLowerCase();
    if (val && !tags.includes(val)) onChange([...tags, val]);
    setInput("");
  };

  const remove = (tag) => onChange(tags.filter((t) => t !== tag));

  const handleKey = (e) => {
    if (e.key === "Enter" || e.key === ",") {
      e.preventDefault();
      add();
    }
    if (e.key === "Backspace" && !input && tags.length)
      remove(tags[tags.length - 1]);
  };

  return (
    <div
      className="border border-border focus-within:border-copper flex flex-wrap gap-1.5 px-2.5 py-2 min-h-[38px] cursor-text"
      onClick={(e) => e.currentTarget.querySelector("input").focus()}
    >
      {tags.map((tag) => (
        <span
          key={tag}
          className="flex items-center gap-1 bg-copper-subtle text-copper font-mono text-xs px-1.5 py-0.5"
        >
          {tag}
          <button
            type="button"
            onClick={() => remove(tag)}
            className="hover:text-destructive transition-colors"
          >
            <X className="w-2.5 h-2.5" />
          </button>
        </span>
      ))}
      <input
        value={input}
        onChange={(e) => setInput(e.target.value)}
        onKeyDown={handleKey}
        onBlur={add}
        placeholder={
          tags.length === 0 ? "work, home, server… (enter to add)" : ""
        }
        className="flex-1 min-w-[120px] font-mono text-xs focus:outline-hidden bg-transparent"
      />
    </div>
  );
}
