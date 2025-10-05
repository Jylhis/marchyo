# Secrets Management with sops-nix

This directory contains encrypted secrets managed by [sops-nix](https://github.com/Mic92/sops-nix).

## Quick Start

### 1. Generate Age Keys

For your user account:
```bash
# Install age
nix-shell -p age

# Generate a new age key
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt

# View your public key (needed for .sops.yaml)
age-keygen -y ~/.config/sops/age/keys.txt
```

For NixOS hosts (using SSH host keys):
```bash
# Get age public key from SSH host key
nix-shell -p ssh-to-age --run "ssh-keyscan hostname | ssh-to-age"

# Or from local SSH host key
nix-shell -p ssh-to-age --run "cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age"
```

### 2. Configure .sops.yaml

Edit `secrets/.sops.yaml` and replace the example age keys with your actual public keys:

```yaml
creation_rules:
  - path_regex: secrets/secrets\.yaml$
    age: >-
      age1your_public_key_here,
      age1another_key_if_needed
```

### 3. Create and Encrypt Secrets

Create a new secrets file:
```bash
# Copy the example
cp secrets/secrets.yaml.example secrets/secrets.yaml

# Edit with sops (encrypts automatically on save)
nix-shell -p sops --run "sops secrets/secrets.yaml"
```

### 4. Use Secrets in NixOS Configuration

Add to your NixOS configuration:

```nix
{
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  # Configure sops
  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
    age.keyFile = "/var/lib/sops-nix/key.txt";

    secrets = {
      # Define secrets to decrypt
      "database/password" = {
        owner = "myservice";
        group = "myservice";
      };
      "api_keys/github" = {};
    };
  };

  # Use secrets in services
  services.myservice = {
    passwordFile = config.sops.secrets."database/password".path;
  };
}
```

## Secrets File Structure

Organize secrets hierarchically in `secrets.yaml`:

```yaml
# Database credentials
database:
  password: supersecret123
  username: dbuser

# API keys
api_keys:
  github: ghp_xxxxxxxxxxxx
  cloudflare: cf_xxxxxxxxxxxx

# SSH keys
ssh:
  deploy_key: |
    -----BEGIN OPENSSH PRIVATE KEY-----
    ...
    -----END OPENSSH PRIVATE KEY-----

# Certificates
certs:
  example_com:
    cert: |
      -----BEGIN CERTIFICATE-----
      ...
      -----END CERTIFICATE-----
    key: |
      -----BEGIN PRIVATE KEY-----
      ...
      -----END PRIVATE KEY-----
```

## Common Operations

### Edit Encrypted Secrets
```bash
nix-shell -p sops --run "sops secrets/secrets.yaml"
```

### View Encrypted Secrets (without editing)
```bash
nix-shell -p sops --run "sops -d secrets/secrets.yaml"
```

### Add a New Secret
```bash
# Edit the file - sops handles encryption
nix-shell -p sops --run "sops secrets/secrets.yaml"

# Add your secret in YAML format, save and exit
```

### Create Host-Specific Secrets
```bash
mkdir -p secrets/hosts
nix-shell -p sops --run "sops secrets/hosts/myhost.yaml"
```

### Create User-Specific Secrets
```bash
mkdir -p secrets/users
nix-shell -p sops --run "sops secrets/users/myuser.yaml"
```

## Key Rotation

When rotating keys (e.g., adding a new host or removing access):

1. Update `.sops.yaml` with new age keys
2. Re-encrypt all secrets:
   ```bash
   nix-shell -p sops --run "sops updatekeys secrets/secrets.yaml"
   ```

3. For multiple files:
   ```bash
   find secrets -type f -name '*.yaml' ! -name '.sops.yaml' ! -name '*.example' | while read file; do
     nix-shell -p sops --run "sops updatekeys $file"
   done
   ```

## Best Practices

1. **Never commit unencrypted secrets** - `.gitignore` is configured to prevent this
2. **Use specific permissions** - Set `owner` and `group` for each secret
3. **Rotate keys regularly** - Update keys when team members change
4. **Keep backups** - Store age private keys securely (encrypted password manager)
5. **Use host-specific files** - Separate secrets by host when needed
6. **Document secret usage** - Comment what each secret is used for

## Troubleshooting

### "no key could be found to decrypt the file"
- Ensure your age key is in `~/.config/sops/age/keys.txt`
- For NixOS, ensure the key is at the path specified in `sops.age.keyFile`
- Verify the key has been added to `.sops.yaml`

### "failed to decrypt data key"
- Your public key may not be in the list of allowed keys
- Re-encrypt with `sops updatekeys` after adding your key to `.sops.yaml`

### Secrets not available at runtime
- Ensure `sops.defaultSopsFile` points to the correct file
- Check that secrets are defined in the `sops.secrets` attribute set
- Verify the age key file exists on the system

## Security Notes

- Age private keys should have `600` permissions
- Store private keys in encrypted locations (LUKS, password managers)
- Use different keys for different trust levels (production vs development)
- Consider using hardware tokens for critical production secrets
- Regularly audit who has access to which keys

## References

- [sops-nix Documentation](https://github.com/Mic92/sops-nix)
- [SOPS Documentation](https://github.com/getsops/sops)
- [Age Documentation](https://github.com/FiloSottile/age)
