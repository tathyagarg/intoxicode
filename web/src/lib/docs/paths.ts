type Path = {
  name: string;
  level?: number;
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
    next: 'arrays'
  },
  'arrays': {
    name: 'Arrays',
    level: 2,
    prev: 'variables',
    next: 'operators'
  },
  'operators': {
    name: 'Operators',
    prev: 'arrays',
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
    next: 'array-functions'
  },
  'array-functions': {
    name: 'Array Functions',
    level: 2,
    prev: 'built-in-functions',
    next: 'directives'
  },
  'directives': {
    name: 'Directives',
    prev: 'array-functions',
  },
}

export default paths;
