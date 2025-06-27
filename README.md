# Affaire Conclue

A modern personal portfolio and presentation website built with Hugo, showcasing professional experience and projects in a clean, static site format.

**🌐 Live Site:** [https://www.affaireconclue.net/](https://www.affaireconclue.net/)

## ✨ Features

- **Static Site Generation**: Built with Hugo for fast performance and easy deployment
- **Responsive Design**: Optimized for all devices and screen sizes
- **Personal Portfolio**: Professional presentation with project showcases
- **Open Source**: Full source code available for transparency and collaboration
- **Modern Stack**: Leveraging Hugo's powerful templating and content management

## 🚀 Quick Start

### Prerequisites

Make sure you have the following installed:

- [Hugo (Extended version)](https://gohugo.io/getting-started/installing/) v0.100.0 or later
- [Git](https://git-scm.com/downloads)

### Local Development

1. **Clone the repository**

   ```bash
   git clone https://github.com/Affaire-Conclue/Affaire-Conclue.git
   cd Affaire-Conclue
   ```

2. **Start the development server**

   ```bash
   hugo server -D
   ```

3. **View the site**
   Open [http://localhost:1313/](http://localhost:1313/) in your browser

The site will automatically reload when you make changes to the source files.

### Building for Production

```bash
# Generate static files
hugo

# Output will be in the ./public directory
```

## 📁 Project Structure

```
├── archetypes/          # Content templates
├── content/             # Markdown content files
├── data/               # Data files (YAML, JSON, TOML)
├── layouts/            # HTML templates
├── static/             # Static assets (images, CSS, JS)
├── themes/             # Hugo themes
├── config.toml         # Site configuration
└── README.md
```

## 🛠️ Development

### Adding Content

Create new content using Hugo archetypes:

```bash
hugo new posts/my-new-post.md
hugo new projects/my-project.md
```

### Customization

- **Configuration**: Edit `config.toml` for site settings
- **Styling**: Modify CSS files in the `static/` directory
- **Templates**: Customize HTML templates in the `layouts/` directory

## 🚀 Deployment

The site is automatically deployed to [https://www.affaireconclue.net/](https://www.affaireconclue.net/) via [GitHub Pages].

For manual deployment:

```bash
hugo --minify
# Upload the ./public directory to your web server
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📧 Contact

- **Website**: [https://www.affaireconclue.net/](https://www.affaireconclue.net/)
- **GitHub**: [@Affaire-Conclue](https://github.com/Affaire-Conclue)
- **Issues**: [GitHub Issues](https://github.com/Affaire-Conclue/Affaire-Conclue/issues)

---

⭐ Star this repository if you find it helpful!
