# Windows Credential Manager Setup

## Recommended SSIS Variable

Add this package variable:

- `User::PatSecretCredentialTarget` (`String`)

Example value:

- `TableauSync/Prod/TableauPAT`

Leave `User::PatSecret` blank after migration, or keep it only as an emergency fallback during rollout.

## Server Setup Steps

1. Log on to the SSIS execution server using the same Windows account that runs the package or SQL Agent job.
2. Open `Credential Manager`.
3. Select `Windows Credentials`.
4. Choose `Add a generic credential`.
5. Set `Internet or network address` to the target name you want the package to use.

Example:

- `TableauSync/Prod/TableauPAT`

6. Set `User name` to any descriptive value.

Example:

- `TableauPAT`

7. Set `Password` to the Tableau PAT secret.
8. Save the credential.
9. Confirm the package execution account can read that credential by testing under the same account context.

## Script Integration

Use `PatSecretResolver.Resolve` to read the PAT secret:

```csharp
string patName = GetStringVariable("User::PatName");
string patSecret = GetStringVariable("User::PatSecret");
string patSecretCredentialTarget = GetStringVariable("User::PatSecretCredentialTarget");

string resolvedPatSecret = PatSecretResolver.Resolve(
    patSecret,
    patSecretCredentialTarget);
```

Or use the overload in `SignInScriptTask.cs`:

```csharp
TableauSignInResult signInResult = signInTask.ExecuteWithCredentialManager(
    serverUrl,
    apiVersion,
    patName,
    patSecret,
    patSecretCredentialTarget,
    siteContentUrl);
```

## Deployment Notes

- The credential must exist on every server that executes the package.
- The credential must be created under the identity that runs the package.
- Do not log or print the resolved PAT secret.
- Rotate the Tableau PAT and update the Credential Manager entry as part of credential maintenance.
