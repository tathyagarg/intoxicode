/** @type {import('tailwindcss').Config} */
module.exports = {
  theme: {
    extend: {
      typography: () => ({
        awesome: {
          css: {
            '--tw-prose-body': 'var(--color-text)',
            '--tw-prose-headings': 'var(--color-blue)',
            '--tw-prose-links': 'var(--color-green)',
            '--tw-prose-bold': 'var(--color-sky)',
            '--tw-prose-code': 'var(--color-sapphire)',
          }
        }
      })
    }
  }
}
