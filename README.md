# Currículo — Adair Martins

Página única de currículo em **HTML**, **CSS** e **JavaScript**.

Este é o projeto para você **abrir no Cursor**, **ver no navegador** e **salvar no GitHub**.

Não precisa instalar plugin extra. O que você precisa é:

1. O aplicativo [Cursor](https://cursor.com/downloads)
2. Uma conta no [GitHub](https://github.com) (já existe: `adaair360-sudo`)
3. Esta pasta do projeto

## Como abrir no Cursor

1. Instale o Cursor e entre na sua conta.
2. Clone este repositório (ou baixe o ZIP e extraia):

```bash
git clone https://github.com/adaair360-sudo/ADAIR-MARTINS.git
```

3. No Cursor: **Arquivo → Abrir pasta** e escolha a pasta `ADAIR-MARTINS`.

Pronto: o projeto fica no computador. Da próxima vez use **Arquivo → Abrir recente**.

## Como ver a página

Dê dois cliques em `index.html` **ou** sirva a pasta:

```bash
python3 -m http.server 8080
```

Depois acesse `http://localhost:8080`.

## Como editar os textos

| O que mudar | Arquivo |
| --- | --- |
| Nome, seções, e-mail, cargos | `index.html` |
| Tradução PT / EN | `js/script.js` |
| Cores, fontes, layout | `css/style.css` |

O e-mail da página já é o real: `adaair360@gmail.com`.

Quando tiver um emprego, um curso ou a cidade, troque os textos de **Percurso** e **Formação**. Não invente experiência.

## Como salvar para não perder

No Cursor, abra **Source Control** (controle de versão):

1. Escreva uma mensagem do que mudou.
2. Clique em **Commit**.
3. Clique em **Sync / Publish** para enviar ao GitHub.

Assim o projeto não some: você clona de novo ou abre a pasta recente.

Conectar o GitHub no Cursor **não** envia os arquivos sozinho. Sem commit + sync, a nuvem não tem a sua pasta.

## Como gerar PDF

Na página, clique em **Imprimir**. No diálogo do navegador escolha **Salvar como PDF**.

## Publicar na internet (GitHub Pages)

Depois de mesclar este projeto na branch `main`:

1. No GitHub: **Settings → Pages**
2. Source: **Deploy from a branch**
3. Branch: `main` / pasta `/ (root)`
4. Save

O endereço fica assim: `https://adaair360-sudo.github.io/ADAIR-MARTINS/`

## O que a página faz

- Layout de uma página, pronto para impressão / PDF
- Tema claro e escuro
- Português e inglês
- Barras de habilidade animadas
- Cópia do e-mail (`adaair360@gmail.com`)
- Menu no celular
