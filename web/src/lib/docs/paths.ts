type Path = {
  name: string;
  icon: string;
  prev?: string;
  next?: string;
};

const paths: Record<string, Path> = {
  'home': {
    name: 'Home',
    icon: 'home',
    next: 'first'
  },
  'first': {
    name: 'First',
    icon: 'first',
    prev: 'home',
  }
}

export default paths;
