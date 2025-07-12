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
    next: 'flow-control'
  },
  'flow-control': {
    name: 'Flow Control',
    prev: 'operators',
    next: 'functions'
  },
  'functions': {
    name: 'Functions',
    prev: 'flow-control',
    next: 'exception-handling'
  },
  'exception-handling': {
    name: 'Exception Handling',
    prev: 'functions',
    next: 'built-in-functions'
  },
  'built-in-functions': {
    name: 'Built-in Functions',
    prev: 'exception-handling',
  },
}

export default paths;
