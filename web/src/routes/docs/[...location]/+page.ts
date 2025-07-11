import paths from "$lib/docs/paths";

export const load = async ({ params }) => {
  const { location } = params;

  if (!paths[location]) {
    return { content: "Document not found." };
  }

  try {
    const mod = await import(`$lib/docs/files/${location}.md?raw`);
    return {
      content: mod.default,
      title: paths[location].name,
      next: {
        name: paths[location].next ? paths[paths[location].next].name : null,
        location: paths[location].next || null,
        icon: paths[location].next ? paths[paths[location].next].icon : null
      },
      prev: {
        name: paths[location].prev ? paths[paths[location].prev].name : null,
        location: paths[location].prev || null,
        icon: paths[location].prev ? paths[paths[location].prev].icon : null
      }
    };
  } catch (e) {
    return { content: "Failed to load document." };
  }
};

