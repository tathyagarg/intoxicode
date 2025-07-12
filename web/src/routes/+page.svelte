<script lang="ts">
  import { onMount } from "svelte";

  onMount(() => {
    const beer = document.getElementById("beer");
    setInterval(() => {
      const beerElement = document.createElement("img");
      beerElement.src = "/assets/beer.png";
      beerElement.className = "absolute w-16 h-16 beer";

      const rotation = Math.random() * 360;

      beerElement.style.left = `${Math.random() * 100}vw`;

      beer?.appendChild(beerElement);
      beerElement.style.setProperty("--rot", `${rotation + 180}deg`);
      beerElement.style.setProperty("--rot-start", `${rotation}deg`);

      setTimeout(() => {
        beerElement.remove();
      }, 10000);
    }, 500);
  });
</script>

<svlte:head>
  <title>Home Page</title>
</svlte:head>

<div
  class="w-screen h-screen fixed top-0 left-0 pointer-events-none"
  id="beer"
></div>
<div class="w-screen h-screen flex flex-col items-center justify-center">
  <h1 class="text-8xl font-bold">Intoxicode</h1>
  <p class="text-2xl mt-4">An esolang to run code in a drunken state</p>
  <div class="grid grid-cols-3 w-2/5 h-20 mt-4">
    <a href="/docs" class="p-1">
      <div
        class="w-full h-full flex items-center justify-center bg-blue rounded-md"
      >
        <span class="text-2xl text-base font-bold">Docs</span>
      </div>
    </a>

    <a href="https://github.com/tathyagarg/intoxicode" class="p-1">
      <div
        class="w-full h-full flex items-center justify-center bg-green rounded-md"
      >
        <span class="text-2xl text-base font-bold">&#9733; on GitHub</span>
      </div>
    </a>
    <a href="/ide" class="p-1">
      <div
        class="w-full h-full flex items-center justify-center bg-red rounded-md"
      >
        <span class="text-2xl text-base font-bold">IDE</span>
      </div>
    </a>
  </div>
</div>

<style>
  @keyframes beer-float {
    0% {
      top: -10%;
      transform: rotate(var(--rot-start));
    }
    100% {
      top: 110%;
      transform: rotate(var(--rot));
    }
  }

  :global(.beer) {
    animation: beer-float 10s linear forwards;
  }
</style>
