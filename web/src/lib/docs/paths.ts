type Path = {
  name: string;
  prev?: string;
  next?: string;
};

const paths: Record<string, Path> = {
  'home': {
    name: 'Home',
    next: 'installation'
  },
  'installation': {
    name: 'Installation',
    prev: 'home',
    next: 'statements'
  },
  'statements': {
    name: 'Statements',
    prev: 'installation',
    next: 'variables'
  },
  'variables': {
    name: 'Variables',
    prev: 'statements',
    next: 'operators'
  },
  'operators': {
    name: 'Operators',
    prev: 'variables',
  },
}

export default paths;
