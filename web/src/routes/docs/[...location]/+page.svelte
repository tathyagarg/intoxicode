<script lang="ts">
  import { marked } from "marked";
  import { getHeadingList, gfmHeadingId } from "marked-gfm-heading-id";
  import type { HeadingData } from "marked-gfm-heading-id";
  import { onMount, tick } from "svelte";

  let { data } = $props();

  $effect(() => {
    if (data.title) document.title = data.title;

    document.addEventListener("keydown", (e) => {
      if (e.key === "ArrowLeft") {
        e.preventDefault();

        if (data.prev?.location) {
          window.location.href = `/docs/${data.prev.location}`;
        }
      } else if (e.key === "ArrowRight") {
        e.preventDefault();

        if (data.next?.location) {
          window.location.href = `/docs/${data.next.location}`;
        }
      }
    });
  });

  let content = $state("");
  let headings: HeadingData[] = $state([]);

  onMount(async () => {
    const renderer = new marked.Renderer();
    renderer.link = ({ href, title, text }) =>
      `<a href="${href}" ${title ? 'title="' + title + '"' : ""} data-sveltekit-reload>${text}</a>`;

    marked.setOptions({
      renderer: renderer,
    });
    marked.use(gfmHeadingId({ prefix: "heading-" }));

    content = await marked(data.content);
    headings = getHeadingList();

    await tick();
    window.Prism.highlightAll();
  });
</script>

<svelte:head>
  <link rel="stylesheet" href="/prism/macchiato.css" />
  <script src="/prism/prism.js" defer></script>
</svelte:head>

<div class="flex flex-row min-h-screen">
  <div class="flex flex-col gap-4 flex-1 bg-mantle shadow-2xl">
    <div class="p-4 prose prose-awesome font-sans min-w-full flex-1">
      {@html content}
    </div>
    <div
      class="w-full h-30 max-h-30 grid grid-cols-2 grid-rows-1 p-2 gap-2 *:rounded-lg *:text-center"
    >
      {#if data.prev?.name}
        <button
          onclick={() =>
            (window.location.href = `/docs/${data.prev?.location}`)}
          class="text-base font-bold cursor-pointer max-h-30 overflow-hidden"
        >
          <div
            class="bg-blue rounded-lg flex flex-col justify-center items-start gap-0 h-30 p-4"
          >
            <h1 class="h-fit text-xl">&#8592; Previous</h1>
            <span class="text-surface1">
              {data.prev?.name}
            </span>
          </div>
        </button>
      {:else}
        <div class="bg-surface2 leading-26">No previous page</div>
      {/if}
      {#if data.next?.name}
        <button
          onclick={() =>
            (window.location.href = `/docs/${data.next?.location}`)}
          class="text-base font-bold cursor-pointer max-h-30 overflow-hidden"
        >
          <div
            class="bg-green rounded-lg flex flex-col justify-center items-end gap-0 h-30 p-4"
          >
            <h1 class="h-fit text-xl">Next &#8594;</h1>
            <span class="text-surface1">
              {data.next?.name}
            </span>
          </div>
        </button>
      {:else}
        <div class="bg-surface2 leading-26">No next page</div>
      {/if}
    </div>
  </div>
  <div class="w-1/3 min-h-full">
    <div class="sticky top-0">
      {#each headings as heading}
        <div class="p-2">
          <a
            href={`#${heading.id}`}
            class="text-lg font-semibold"
            style={`margin-left: ${heading.level * 20}px;`}
          >
            {@html heading.text}
          </a>
        </div>
      {/each}
    </div>
  </div>
</div>
