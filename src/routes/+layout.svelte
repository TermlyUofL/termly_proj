<script>
	import favicon from '$lib/assets/favicon.svg';

	let { children } = $props();
</script>
<header>
	<a class="termly_navbar" href="/">Tm</a> <!-- This is the Termly navbar -->
	<h1><span>Te</span>rmly</h1>  <!-- This is the Termly header -->
	<div></div> <!-- This is the empty div on the right side of the header -->
	
</header>
		
<svelte:head>
	<link rel="icon" href={favicon} />
</svelte:head>
<main>
{@render children()}
</main>

<style>
	:global(body){ /* This is the body */
		margin: 0;
		font-family: 'Inter', Bold, sans-serif;
		background-color: #e5e5e5;	}
	header { /* This is the header */
		display: grid;
		grid-template-columns: 1fr auto 1fr;
		height: 30px;
		align-items:center;
		padding: 0 20px;
		background-color: black;
		color: white;
	}
	.termly_navbar { /* This is the navbar */
		justify-self: start;
		text-decoration: none;
		background-color: #c62828;
		font-family: 'Inter', Bold, sans-serif;
		font-size: 11px;
		color: white;
		padding:0.2rem 1.2rem;
		border-radius: 5px;
	}
	h1 {/* This is the "rmly" in Termly */
		margin: 0;
		font-size: 1.5rem;
	}
	h1 span {/* This is the "Te" in Termly*/
		color: #c62828;
	}
	

</style>