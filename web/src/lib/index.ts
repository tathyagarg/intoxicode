// place files you want to import through the `$lib` alias in this folder.
export function make_target(os: string): string {
  let res = `intoxicode-${os}-x86_64`
  if (os === 'windows') {
    res += '.exe'
  }

  return res;
}
