export default function PageHeader({ title, subtitle, actions }) {
  return (
    <div className="border-b border-border px-6 py-5 flex items-start justify-between gap-4">
      <div>
        <h1 className="text-lg font-semibold text-foreground font-mono tracking-tight">
          {title}
        </h1>
        {subtitle && (
          <p className="text-sm text-muted-foreground mt-0.5">{subtitle}</p>
        )}
      </div>
      {actions && (
        <div className="flex items-center gap-2 shrink-0">{actions}</div>
      )}
    </div>
  );
}
