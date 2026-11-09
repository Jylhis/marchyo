export default function EmptyState({ icon: Icon, title, description, action }) {
  return (
    <div className="flex flex-col items-center justify-center py-20 px-6 text-center">
      {Icon && (
        <div className="w-12 h-12 border border-border flex items-center justify-center mb-4 text-muted-foreground">
          <Icon className="w-5 h-5" />
        </div>
      )}
      <p className="font-mono text-sm font-medium text-foreground mb-1">
        {title}
      </p>
      {description && (
        <p className="text-sm text-muted-foreground max-w-sm mb-4">
          {description}
        </p>
      )}
      {action}
    </div>
  );
}
