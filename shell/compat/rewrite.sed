s/(^|[^.A-Za-z0-9_])import qs\.Ui\b/\1import qs.compat.Ui/g
s/(^|[^.A-Za-z0-9_])import qs\.Commons\b/\1import qs.compat.Commons/g
s/(^|[^.A-Za-z0-9_])Color\.([A-Za-z])/\1CompatColor.\2/g
s/\bCommons\.Color\.([A-Za-z])/Commons.CompatColor.\1/g
s/(^|[^.A-Za-z0-9_])o\.workspaces\./\1marchyo.workspaces./g
