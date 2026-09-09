# Publish on GitHub

## Repository form

| Field | Value |
| --- | --- |
| Owner | `ViggleH` |
| Repository name | `multifidelity-warmstart` |
| Description | MATLAB code, HIGGS experiment data, and reproducible diagnostics for cost-aware multi-fidelity warm starts. |
| Visibility | Public |
| Add README | Off; this package includes README.md |
| Add .gitignore | No .gitignore; this package includes one |
| Add license | No license; the data-source notice is included separately |

Create the repository, then upload the **contents** of the extracted
`multifidelity-warmstart` folder to its root, preserving subfolders. Do not
upload only the ZIP or place the project one directory below the repository root.
The largest included file is below GitHub's 25 MiB per-file browser-upload limit.
If the file picker hides `.gitignore`, add it separately or use GitHub Desktop/Git.

Commit message: `Add HIGGS experiment code, data, analysis, and project page`.

## GitHub Pages

After the initial files are on the `main` branch:

1. Open **Settings > Pages**.
2. Under **Source**, choose **Deploy from a branch**.
3. Select **main** and **/docs**, then **Save**.
4. Wait for the Pages deployment to complete and open the URL shown by GitHub.

With the owner and repository name above, the expected URL is
`https://viggleh.github.io/multifidelity-warmstart/`.
This URL is only a destination until a successful deployment is confirmed.

Repository files are linked from the static homepage. If the repository owner,
name, or default branch differs, update the URLs in `docs/index.html` first.

## Using Git instead of the browser upload

Run these commands inside the extracted project folder after creating an empty repository:

```bash
git init -b main
git add .
git commit -m "Add HIGGS experiment code, data, analysis, and project page"
git remote add origin https://github.com/ViggleH/multifidelity-warmstart.git
git push -u origin main
```

Authenticate through your GitHub client when prompted. Do not put access tokens
into the code or repository. These commands assume a new empty repository.

Official instructions: [uploading files](https://docs.github.com/en/repositories/working-with-files/managing-files/adding-a-file-to-a-repository)
and [configuring GitHub Pages](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site).
