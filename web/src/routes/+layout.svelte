<script lang="ts">
  import "../app.css";

  let { children } = $props();
  import { onMount } from "svelte";

  onMount(() => {
    const canvas = document.createElement("canvas");
    const size = 400;
    canvas.width = size;
    canvas.height = size;
    const ctx = canvas.getContext("2d");

    const imageData = ctx.createImageData(size, size);
    const data = imageData.data;

    for (let i = 0; i < data.length; i += 4) {
      const shade_range = Math.random();
      const shade = (shade_range > 0.5 ? 255 : 0) * Math.random() * 0.75;

      data[i] = shade;
      data[i + 1] = shade;
      data[i + 2] = shade;
      data[i + 3] = 10;
    }

    ctx.putImageData(imageData, 0, 0);
    document.body.style.backgroundImage = `url(${canvas.toDataURL()})`;
  });
</script>

<svelte:head>
  <meta property="og:title" content="Intoxicode - An esolang" />
  <meta
    property="og:description"
    content="Run code like a drunk person would write it"
  />
  <meta
    name="description"
    content="Run code like a drunk person would write it"
  />
  <meta property="og:site_name" content="arson.dev" />
  <meta property="og:url" content="https://intoxicode.arson.dev" />
  <meta property="og:image" content="/assets/preview.png" />
</svelte:head>

<div
  class="bg-crust text-subtext0 p-4 flex items-center gap-8 *:hover:text-text"
>
  <a href="/">Home</a>
  <a href="/docs">Docs</a>
  <button onclick={() => (window.location.href = "/ide")}>IDE</button>
</div>
<div class="min-h-screen min-w-screen max-w-screen text-text flex flex-col">
  <div class="flex-1">
    {@render children()}
  </div>
  <div
    class="text-sm text-subtext0 p-4 bg-crust flex justify-center gap-8 items-center"
  >
    <div class="flex gap-2 items-center">
      <span>Powered by</span><img
        src="/svelte.svg"
        alt="SvelteKit"
        class="h-6"
      />
    </div>
    <div>
      Inspired by <a href="https://github.com/cyteon/modu" class="text-blue"
        >Modu</a
      >
    </div>
    <div>
      &#9733; on <a
        href="https://github.com/tathyagarg/intoxicode"
        class="text-blue">GitHub</a
      >
    </div>
  </div>
</div>
