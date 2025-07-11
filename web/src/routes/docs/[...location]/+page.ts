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
      title: paths[location].name
    };
  } catch (e) {
    return { content: "Failed to load document." };
  }
};

