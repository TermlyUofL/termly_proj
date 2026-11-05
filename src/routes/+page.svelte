
<script>  
    // ===================================================================
    // IMPORTS
    // ===================================================================
    // subjects:     the list of subjects shown in the "Subject" dropdown.
    // onMount:      a Svelte helper that runs code once the page has loaded
    //               in the browser.
    // SchedulePlan: the sidebar component that lists the courses in the plan.
    import { subjects } from '$lib/subjects.js';
    import { onMount } from 'svelte';
    import SchedulePlan from '$lib/SchedulePlan.svelte';
    // ===================================================================
    // INITIAL SEARCH
    // ===================================================================
    // When the page first opens, run a search with the default filters
    // (everything set to "All") so the results list isn't empty.
    onMount(() => {
    applyFilters();
    });
// ===================================================================
// CALENDAR GRID SETUP
// ===================================================================
// This is the script section for the calendar   
    // The columns of the calendar (one per weekday).
    const days = [ 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
    // The rows of the calendar (one per hour, 7 AM to 8 PM).
    const hours = [ '7:00AM', '8:00AM', '9:00AM', '10:00AM', '11:00AM', '12:00PM', '1:00PM', '2:00PM', '3:00PM', '4:00PM', '5:00PM', '6:00PM', '7:00PM', '8:00PM'];
    
// ===================================================================
// SEARCH FILTERS
// ===================================================================
// This is the script section for the search filters
    // Each variable below is "bound" to one control in the filter bar, so
    // typing or choosing an option updates it automatically.
    // $state(...) makes a variable reactive: when it changes, Svelte
    // re-draws any part of the page that uses it.
    // 'All' means "don't filter on this".
    let search = $state('');
    let subject = $state('All');
    let session = $state('All');
    let mode = $state('All');
    let career = $state('All');
    let prereq = $state(false);

    // the real dropdown values, loaded from the backend
    let filterOptions = $state({ subjects: [], sessions: [], modes_of_instruction: [], careers: [] });

    // subject codes from the backend, with names from subjects.js where we know them
    let subjectOptions = $derived(
        filterOptions.subjects.map(code => {
            const known = subjects.find(s => s.code === code);
            return { code, name: known ? known.name : code };
        })
    );

    onMount(async () => {
        try {
            const res = await fetch('/api/filters');
            if (res.ok) filterOptions = await res.json();
        } catch {
            // if this fails, the dropdowns just show "All"
        }
    });
    
    // results:  the courses the server sent back for the current filters.
    // loading:  true while waiting for the server (shows "Searching...").
    // errorMsg: a message to show if the search failed.
    let results = $state([]);
    let loading = $state(false);
    let errorMsg = $state('');

    
    
    // This is function for applying the search filters and fetching the results from the API
    // How it works:
    //   1. Build a query string like "q=calc&subject=MATH" from the filters,
    //      skipping any filter that is empty or left on "All".
    //   2. Ask the backend for the matching courses.
    //   3. Save the answer in `results`, or show an error message.
    // `async` lets us use `await` to wait for the server without freezing
    // the page.
    let total = $state(0);   // how many courses match in total
    let page = $state(1);    // which page of results is loaded

    async function fetchCourses(pageNum) {
        const params = new URLSearchParams();
        if (search.trim()) params.set('q', search.trim());
        if (subject !== 'All') params.set('subject', subject);
        if (session !== 'All') params.set('session', session);
        if (mode !== 'All') params.set('mode', mode);
        if (career !== 'All') params.set('career', career);
        if (prereq) params.set('has_prereq', 'yes');
        params.set('page', pageNum);
        params.set('per_page', 50);

        loading = true;
        errorMsg = '';
        try {
            const res = await fetch(`/api/courses?${params}`);
            const data = await res.json();
            if (res.ok) {
                // page 1 replaces the list, later pages add to it
                results = pageNum === 1 ? data.courses : [...results, ...data.courses];
                total = data.total;
                page = data.page;
            } else {
                errorMsg = data.error;
                results = [];
            }
        } catch {
            errorMsg = 'Could not reach the server';
        }
        loading = false;
    }

    function applyFilters() { fetchCourses(1); }
    function loadMore() { fetchCourses(page + 1); }

    
    // ===================================================================
    // SCHEDULE PLAN
    // ===================================================================
    // courses: the courses the student has added to their plan (shown in
    // the SchedulePlan sidebar). It is saved to localStorage further down.
    let courses = $state([]);
    
    // This is functions for adding and removing courses from the schedule plan
    // "Add to Schedule Plan" button. [...courses, course] builds a new list
    // with the old courses plus the new one.
    function addToPlan(course) {
        courses = [...courses, course];
    }
    // true if this course is already in the plan (used to disable its
    // Add button so it can't be added twice).
    function inPlan(course) {
    return courses.some(c => c.course_code === course.course_code);
    }
    // Keeps every course except the one with this code. Called by the
    // remove button in the SchedulePlan sidebar.
    function removeFromPlan(courseCode) {
        courses = courses.filter(c => c.course_code !== courseCode);
    }


    // ===================================================================
    // EXCLUDING TIMES ON THE CALENDAR (CLICK AND DRAG)
    // ===================================================================
    // excluded:   the cells the student has painted red, stored like
    //             { "Monday-9:00AM": true }. Red means "don't schedule me here".
    // dragging:   true while the mouse button is held down on the calendar.
    // paintValue: what the current drag does: true = paint red, false = erase.
    // dragging and paintValue are plain variables (not $state) because
    // nothing on screen needs to re-draw when they change.
    let excluded = $state({});
    let dragging = false;
    let paintValue = true;
// This is the functions for the calendar drag 
    // Mouse pressed on a cell. If that cell was empty, this drag paints red;
    // if it was already red, this drag erases.
    function startDrag(day, hour) {
        const key = `${day}-${hour}`;
        paintValue = !excluded[key];   // first cell decides: paint red or erase
        dragging = true;
        excluded[key] = paintValue;
    }

    // Mouse moved into a cell. Only does something while the button is held.
    function dragOver(day, hour) {
        if (dragging) excluded[`${day}-${hour}`] = paintValue;
    }

    // Mouse released anywhere on the page (see <svelte:window> in the markup).
    function stopDrag() {
    dragging = false;
    }

    // "Reset" button: clear every red cell.
    function resetAll() {
    excluded = {};
    }

    // "Exclude all" button: mark every cell (every day x every hour) red.
    function excludeAll() {
        const all = {};
        for (const day of days) {
            for (const hour of hours) {
                all[`${day}-${hour}`] = true;
        }
    }
    excluded = all;
    }


    // ===================================================================
    // TURNING RED CELLS INTO TIME RANGES FOR THE SERVER
    // ===================================================================
    // The server wants excluded times like { day: 'M', start: '09:00', end: '11:00' }.
    // dayCode turns full day names into the short codes it expects.
    const dayCode = { Monday: 'M', Tuesday: 'T', Wednesday: 'W', Thursday: 'Th', Friday: 'F' };

// Turns a row label into a 24-hour number: "9:00AM" -> 9, "1:00PM" -> 13.
// The regex pulls out the hour and AM/PM. % 12 turns 12 into 0, so
// "12:00PM" becomes 0 + 12 = 12.
function hourNumber(label) {
    const [, h, , ap] = label.match(/(\d+):(\d+)(AM|PM)/);
    return (Number(h) % 12) + (ap === 'PM' ? 12 : 0);
}

// 9 -> "09:00" (the text format the server expects).
function fmt(n) {
    return String(n).padStart(2, '0') + ':00';
}

// Walks down each day's column from top to bottom and merges runs of
// red cells that touch into one range. So red at 9, 10 and 11 AM becomes
// a single { start: "09:00", end: "12:00" } instead of three entries.
function getExcludedTimes() {
    const out = [];
    for (const day of days) {
        let start = null;
        for (const hour of hours) {
            const isRed = excluded[`${day}-${hour}`];
            const n = hourNumber(hour);
            // A red cell and no range open yet: start a new range here.
            if (isRed && start === null) start = n;
            // The first non-red cell after a run of red ones closes the range.
            // If the run began in the top row (7 AM), it starts at 00:00, so
            // classes earlier than the calendar shows are blocked too.
            if (!isRed && start !== null) {
                out.push({ day: dayCode[day], start: fmt(start < 8 ? 0 : start), end: fmt(n) });
                start = null;
            }
        }
        // The run went all the way to the bottom of the column, so close it
        // at the end of the last row (the 8 PM row ends at 21:00).
        if (start !== null) {
            const last = hourNumber(hours[hours.length - 1]);
            out.push({ day: dayCode[day], start: fmt(start < 8 ? 0 : start), end: fmt(last + 1) });
        }
    
    }
return out;
}
// ===================================================================
// TURNING SERVER SECTIONS INTO CALENDAR BLOCKS
// ===================================================================
// The server describes each class section with text, like
// meeting_days "MWF" and start_time "09:00". The helpers below turn
// that into "blocks" the calendar grid knows how to draw.
// Maps every day abbreviation the server might use to a full day name.
// Different data spells Tuesday and Thursday in different ways.
const dayMap = {
    M: 'Monday', T: 'Tuesday', W: 'Wednesday', R: 'Thursday', F: 'Friday',
    Tu: 'Tuesday', Th: 'Thursday', Tr: 'Thursday'
};

// "M W F", "MWF", "T Tr", "TR", "TuTh"  ->  list of day names
// Splits the text on spaces, then pulls out each day code. The two-letter
// codes (Tu, Th, Tr) come first in the regex so "Th" isn't read as "T".
// new Set(...) removes any duplicates.
function toDays(meetingDays) {
    const out = [];
    for (const token of meetingDays.split(/\s+/).filter(Boolean)) {
        for (const part of token.match(/Tu|Th|Tr|[MTWRF]/g) || []) {
            out.push(dayMap[part]);
        }
    }
    return [...new Set(out)];
}

// "14:20" -> 14.333
// A plain number is easy to do math with when placing and sizing blocks.
function toHours(t) {
    const [h, m] = t.split(':').map(Number);
    return h + m / 60;
}

// "14:20" -> "2:20 PM"
// `h % 12 || 12` turns both 0 and 12 into 12 (for 12 AM and 12 PM).
function fmtClock(t) {
    const [h, m] = t.split(':').map(Number);
    return `${h % 12 || 12}:${String(m).padStart(2, '0')} ${h >= 12 ? 'PM' : 'AM'}`;
}

// one section can meet on several days, so it makes one block per day
function sectionToBlocks(s) {
    return toDays(s.meeting_days).map(day => ({
        code: s.course_code,
        name: s.course_name,
        day,
        start: toHours(s.start_time),
        end: toHours(s.end_time),
        time: `${fmtClock(s.start_time)} – ${fmtClock(s.end_time)}`,
        room: s.section_location,
        instructor: s.instructor_name
    }));
}

// ===================================================================
// GENERATED SCHEDULES
// ===================================================================
// schedules:  every schedule the server came up with. Each one is a
//             combination of sections whose times don't clash.
// current:    which schedule is being shown (0 = the first one).
// problems:   messages shown above the calendar (e.g. a course that
//             couldn't fit).
// generating: true while waiting for the server.
let schedules = $state([]);
let current = $state(0);
let problems = $state([]);
let generating = $state(false);

// $derived(...) values recalculate automatically when the things they use
// change, so switching `current` updates all three of these.
// currentSchedule: the schedule being shown (or null if there are none).
// schedule:        its in-person sections, turned into calendar blocks.
// onlineSections:  its online sections. They have no meeting time, so
//                  they are listed under the calendar instead of on it.
let currentSchedule = $derived(schedules[current] ?? null);
let schedule = $derived(currentSchedule ? currentSchedule.calendar.flatMap(sectionToBlocks) : []);
let onlineSections = $derived(currentSchedule ? currentSchedule.online : []);

// ">" button. % wraps around: after the last schedule, go back to the first.
function nextSchedule() {
    if (schedules.length) current = (current + 1) % schedules.length;
}

// "<" button. Adding schedules.length before % stops the number going
// negative, so going back from the first schedule lands on the last.
function prevSchedule() {
    if (schedules.length) current = (current - 1 + schedules.length) % schedules.length;
}

// These two are plain variables (not $state) on purpose: changing them
// shouldn't re-draw anything or re-run the $effect further down.
let hasGenerated = false;   // plain variable: true after the first Generate
let requestId = 0;          // plain variable: numbers each request

// Sends the plan's course codes and the red (excluded) times to the
// server, which sends back every schedule that fits. Called by the
// "Generate" button in the SchedulePlan sidebar, and automatically by
// the $effect below after the plan or the red cells change.
async function generateSchedules() {
    // Nothing to schedule yet: show a hint and stop here.
    if (courses.length === 0) {
        problems = ['Add at least one course to the plan first.'];
        return;
    }

    hasGenerated = true;
    const myId = ++requestId;       // this request's number
    generating = true;
    problems = [];

    try {
        // POST sends data in the request body. JSON.stringify turns the
        // JavaScript object into text the server can read.
        const res = await fetch('/api/schedules/generate', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                course_codes: courses.map(c => c.course_code),
                excluded_times: getExcludedTimes()
            })
        });
        const data = await res.json();

        // A newer request has started since this one, so ignore this answer.
        if (myId !== requestId) return;

        if (res.ok) {
            // Success: keep the schedules and show the first one.
            schedules = data.schedules;
            problems = data.problems;
            current = 0;
        } else {
            // The server answered with an error message.
            schedules = [];
            problems = [data.error];
        }
    } catch {
        // The request failed completely (server down, no internet).
        // Again, ignore it if a newer request has started.
        if (myId !== requestId) return;
        schedules = [];
        problems = ['Could not reach the server'];
    }

    generating = false;
}

// ===================================================================
// AUTO-REGENERATE
// ===================================================================
// After the student has pressed Generate once, keep the schedules up to
// date by themselves whenever the plan or the red cells change.
// regenTimer holds the id of the waiting setTimeout so it can be cancelled.
let regenTimer;

// $effect runs once at the start, then again whenever a reactive value it
// reads changes. The function it returns (the "cleanup") runs before the
// next run, cancelling any timer that hasn't fired yet.
$effect(() => {
    // Reading these two makes Svelte watch them.
    JSON.stringify(excluded);
    courses.map(c => c.course_code);

    // Don't run until the student has pressed Generate once.
    if (!hasGenerated) return;

    // Wait 400 ms after the last change, so dragging across many cells
    // sends one request instead of dozens.
    clearTimeout(regenTimer);
    regenTimer = setTimeout(() => {
        if (courses.length === 0) {
            requestId++;            // cancel any request still on its way
            schedules = [];
            problems = [];
            generating = false;
        } else {
            generateSchedules();
        }
    }, 400);

    return () => clearTimeout(regenTimer);
});
    // ===================================================================
    // CALENDAR DRAWING HELPERS
    // ===================================================================
    // Returns the class blocks that START during this hour on this day.
    // Each block is drawn inside the cell where it starts, then moved and
    // stretched with CSS (top/height) to match its real start and end times.
    function blocksAt(day, hour) {
        return schedule.filter(b => b.day === day && Math.floor(b.start) === hourNumber(hour));
    }
    // ===================================================================
    // FAVORITES
    // ===================================================================
    // favorites:  schedules saved with the "Favorite" button. Each one
    //             looks like { key, name, schedule }.
    // favCounter: used to name them Schedule1, Schedule2, ...
    let favorites = $state([]);
    let favCounter = 1;

    // Saves the schedule being shown. Its key is its section numbers (CRNs)
    // joined together, e.g. "12345,23456", so the same schedule can't be
    // saved twice.
    function addFavorite() {
        if (!currentSchedule) return;
        const key = currentSchedule.crns.join(',');
        if (favorites.some(f => f.key === key)) return;    // already saved
        favorites = [...favorites, { key, name: `Schedule${favCounter++}`, schedule: currentSchedule }];
    }

    // The ⊗ button next to a favorite.
    function removeFavorite(key) {
        favorites = favorites.filter(f => f.key !== key);
    }

    // "Confirm" button: show only this favorite on the calendar.
    function confirmFavorite(fav) {
        schedules = [fav.schedule];
        current = 0;
    }
    // ===================================================================
    // SAVE AND LOAD (localStorage)
    // ===================================================================
    // localStorage is a small storage area in the browser that survives page
    // refreshes. It remembers the plan, the red cells and the favorites.
    // It can only store text, so JSON.stringify saves and JSON.parse loads.
    // loaded stays false until the saved data has been read, so the effect
    // below doesn't overwrite it with empty values first.
    let loaded = false;

    // runs once, when the page opens in the browser
    // (onMount matters here: SvelteKit also builds the page on the server,
    // where localStorage doesn't exist. onMount only runs in the browser.)
    onMount(() => {
        const savedPlan = localStorage.getItem('plan');
        if (savedPlan) courses = JSON.parse(savedPlan);

        const savedExcluded = localStorage.getItem('excluded');
        if (savedExcluded) excluded = JSON.parse(savedExcluded);

        const savedFavorites = localStorage.getItem('favorites');
        if (savedFavorites) favorites = JSON.parse(savedFavorites);

        loaded = true;
    });

    // runs again whenever any of the three changes
    $effect(() => {
        const planText = JSON.stringify(courses);
        const excludedText = JSON.stringify(excluded);
        const favoritesText = JSON.stringify(favorites);

        // The three values are read ABOVE this line on purpose: Svelte only
        // watches values the effect actually reads, so reading them first
        // makes the effect re-run whenever any of them changes.
        if (!loaded) return;
        localStorage.setItem('plan', planText);
        localStorage.setItem('excluded', excludedText);
        localStorage.setItem('favorites', favoritesText);
    });
</script>


<!-- Listen for mouse-up on the whole window, so letting go of the button anywhere (even off the calendar) ends a drag. -->
<svelte:window onmouseup={stopDrag} />
<!-- Page layout: a main column on the left and a sidebar (plan + favorites) on the right. -->
<div class="layout">
<!-- Main column: calendar, search filters and search results. -->
<div class="main_col">
<!--This is the section for the calendar  -->
<section class="calendar_text"> <!-- This is the section for the calendar text -->
   
    <!-- Header row: title, instructions, buttons and the schedule switcher. -->
    <div class="calender_toptext"> 
    <div class="calender_lefttoptext">
    <h2> Weekly Schedule</h2>
    <p class="sub">Fall Semester</p>
    </div>
    
    <div class="calender_middletoptext">Click and drag to exclude times out of calendar. Click button to exclude all times.</div>
    
    <!-- Buttons for the red (excluded) cells, plus one to save the current schedule. -->
    <div class="calender_righttoptext">  
        <button class="btn-red" onclick={excludeAll}>Exclude all</button>
        <button class="btn-red" onclick={resetAll}>Reset</button>
        <button class="btn-red" onclick={addFavorite}>Favorite</button>

    </div>
    <!-- Flip between the generated schedules. -->
    <div class="calender_scroll">
        <button class="btn-white" onclick={prevSchedule}>&lt;</button>
        <p>{schedules.length ? `Schedule ${current + 1} of ${schedules.length}` : 'No schedules'}</p>
        <button class="btn-white" onclick={nextSchedule}>&gt;</button>
    </div>
    
    </div>
    <!-- Messages from schedule generation. Each is either plain text or { course_code, reason }. -->
    {#each problems as p}
    <p class="hint">
        {typeof p === 'string' ? p : `${p.course_code}: ${p.reason}`}
    </p>
    {/each} 
    <div class="calendar">  <!-- This is the calendar grid -->
        <!-- Top row: an empty corner cell, then one heading per day. -->
        <div class="corner"></div> <!-- This is the corner cell -->
        {#each days as day}
            <div class="day">{day}</div>
        {/each}

    <!-- One row per hour: the time label, then one clickable cell per day. -->
    {#each hours as hour}
        <div class="hour">{hour}</div>
        {#each days as day}
        <!-- A cell turns red (class:excluded) when it's in `excluded`. Pressing the mouse starts a drag; moving into a cell while dragging paints it. -->
        <!-- svelte-ignore a11y_no_static_element_interactions -->
        <div
            class="cell"
            class:excluded={excluded[`${day}-${hour}`]}
            onmousedown={() => startDrag(day, hour)}
            onmouseenter={() => dragOver(day, hour)}
        >
            <!-- Classes that start in this hour. top = how far into the hour it starts; height = how long it lasts (1 hour = 100% of a cell). -->
            {#each blocksAt(day, hour) as b}
                <div
                    class="class_block"
                    style="top: {(b.start % 1) * 100}%; height: {(b.end - b.start) * 100}%;"
                >
                    <p class="block_title">{b.code} – {b.name}</p>
                    <p class="block_info">{b.time}</p>
                    {#if b.room}<p class="block_info">{b.room}</p>{/if}
                    {#if b.instructor}<p class="block_info">{b.instructor}</p>{/if}
                </div>
            {/each}
        </div>
        {/each}
    {/each}
    </div>
    <!-- Online classes have no meeting time, so they're listed here instead of on the grid. -->
    <div class="calender_bottomtext">
  <h3>Online Classes</h3>
  <p class="sub1">COURSES ({onlineSections.length})</p>

  <div class="online_list">
    {#each onlineSections as s}
      <div class="online_card">
        <p class="online_code">{s.course_code} {s.section_type}</p>
        <p class="online_text">{s.course_name} ({s.credit} cr)</p>
        <p class="online_text">{s.instructor_name}</p>
      </div>
    {/each}
  </div>
</div>
    
        
    
</section>

<!--This is the section for the search filters  -->
<section class="search_filters">
 <!-- Each control is bound (bind:value / bind:checked) to a variable in the script, which updates as you type or choose. -->
 <input type="text" placeholder="Search courses..." bind:value={search} />

 <label>Subject:
  <select bind:value={subject}>
    <option value="All">All</option>
    {#each subjectOptions as s}
      <option value={s.code}>{s.name === s.code ? s.code : `${s.name} (${s.code})`}</option>
    {/each}
  </select>
</label>

<label>Session:
  <select bind:value={session}>
    <option value="All">All</option>
    {#each filterOptions.sessions as s}
      <option value={s}>{s}</option>
    {/each}
  </select>
</label>

<label>Mode:
  <select bind:value={mode}>
    <option value="All">All</option>
    {#each filterOptions.modes_of_instruction as m}
      <option value={m}>{m}</option>
    {/each}
  </select>
</label>

<label>Career:
  <select bind:value={career}>
    <option value="All">All</option>
    {#each filterOptions.careers as c}
      <option value={c}>{c}</option>
    {/each}
  </select>
</label>

  <!-- Checked = only show courses that have a prerequisite. -->
  <label><input type="checkbox" bind:checked={prereq} /> Pre-req needed</label>

  <!-- The search only runs when this is clicked, not on every keystroke. -->
  <button class="btn-red" onclick={applyFilters}>Apply Filters</button>

</section>

<!-- This is the section for the search results -->
<section class="results">
  <h3>Course Search Results</h3>
  <p class="hint">Showing {results.length} of {total} courses</p>

    {#if results.length < total}
        <button class="btn-red" onclick={loadMore} disabled={loading}>Load more</button>
    {/if}
  <p class="hint">Click on class name to see details about class</p>

  <!-- Status message: searching, an error, or nothing found. -->
  {#if loading}
    <p>Searching...</p>
  {:else if errorMsg}
    <p class="hint">{errorMsg}</p>
  {:else if results.length === 0}

    <p>No courses found.</p>
  {/if}

  <!-- One card per course. The name links to its details page (/course/CODE). The button is disabled once the course is in the plan. -->
  <div class="cards">
    {#each results as course}
      <div class="course-card">
        <p class="meta">{course.course_code} • {course.credit} Credits</p>
        <a class="title" href="/course/{course.course_code}">{course.course_name}</a>
        <button
        class="btn-red"
        onclick={() => addToPlan(course)}
        disabled={inPlan(course)}
    >
            {inPlan(course) ? 'In Schedule Plan' : 'Add to Schedule Plan'}
        </button>
      </div>
    {/each}
  </div>

</section>

</div>

<!-- This is the section for the schedule plan -->
<div class="side_col">
<!-- Sidebar component. It gets the plan, a function to remove a course, a function to generate schedules, and whether generation is running ({generating} is short for generating={generating}). -->
<SchedulePlan plan={courses} onremove={removeFromPlan} ongenerate={generateSchedules} {generating} />

<!-- Saved favorite schedules. "Confirm" shows that schedule on the calendar; ⊗ removes it. -->
<section class="favorites">
  <h3>Favorites</h3>
  <p class="fav_label">FAVORITE SCHEDULES ({favorites.length})</p>


    <div class="fav_list">
        {#each favorites as fav}
            <div class="fav_item">
                <div class="fav_row">
                    <p class="fav_name">{fav.name}</p>
                    <button class="btn-red" onclick={() => confirmFavorite(fav)}>Confirm</button>
                </div>
                <button class="plan_remove" onclick={() => removeFavorite(fav.key)}>⊗</button>
            </div>
        {/each}
    </div>

</section>
</div>
</div>

<style>
/* =============================================================== */
/* PAGE LAYOUT                                                   */
/* =============================================================== */
    .layout 
    {
    display: grid;
    grid-template-columns: 1fr 320px;
    gap: 1rem;
    align-items: start;
    }

    .main_col 
    {
    min-width: 0;
    }

/* =============================================================== */
/* SHARED (used in several places)                               */
/* =============================================================== */
    .btn-red
    {
        background-color: #c62828;
        color: white;
        border: none;
        padding: 0.5rem 1rem;
        border-radius: 5px;
        cursor: pointer;
    }

    .hint {
        margin: 0.25rem 0 0.75rem;
        font-size: 0.75rem;
        color: #c62828;
    }

/* =============================================================== */
/* CALENDAR CARD AND HEADER                                      */
/* =============================================================== */
    .calendar_text
    {
        background-color: white;
        margin: 1rem;
        border-radius: 0.5rem;
    }

    .calender_toptext
    {
        display: flex;
        justify-content: space-between;
        align-items: center;
        
    }

    .calender_lefttoptext
    {
        max-width: 150px;
        max-height: 100px;
        flex-shrink: 0;
        white-space: nowrap;
        margin-left: 1rem;

    }

    .calender_toptext h2
    {
        margin: 0;
        font-size: 1.5rem;
    }

    .calender_toptext .sub
    {
        margin: 0;
        font-size: 0.8rem;
        color: #6b7280;
    }

    .calender_middletoptext
    {
        max-width: 120px;
        max-height: 100px;
        text-align: center;
        margin-left: 2rem;
        color: #c62828;
    }

    .calender_scroll
    {
        display: flex;
        align-items: center;
        gap: 1rem;
        
    }

    .calender_scroll p
    {
        margin: 0;
        font-weight: bold;
        font-size: 1rem;
    }

    .btn-white{
        width: 32px;
        height: 32px;
        display: flex;
        align-items: center;
        justify-content: center;
     background: white;
        border: 2px solid #e5e7eb;
        border-radius: 6px;
        font-size: 1.2rem;
        font-weight: 700;
        color: #333;
        cursor: pointer;
    }

    .calendar_text .hint 
    {
    margin: 0.5rem 1rem;
    font-size: 0.85rem;
    }

/* =============================================================== */
/* CALENDAR GRID                                                 */
/* =============================================================== */
    .calendar
    {
        display: grid;
        grid-template-columns: 70px repeat(5, 1fr);
        border-bottom: 1px solid #e5e7eb;
        padding: 10px;
    }

    .corner{
        background-color: #e5e7e5;
        border-left: 1px solid #e5e7eb;
        border-top: 1px solid #e5e7eb;
    }

    .day
    {
        text-align: center;
        font-weight: bold;
        padding: 10px;
        background-color: #e5e7e5;
        border-left: 1px solid rgb(202, 190, 190);
        border-top: 1px solid rgb(202, 190, 190);
    }

    .hour
    {
        height: 40px;
        box-sizing: border-box;
        padding: 0.25rem 0.5rem 0.25rem 15px;
        font-size: 0.8rem;
        color: #6b7280;
        border-left: 1px solid #e5e7eb;
    }

    .cell
    {
        height: 100px;
        position: relative;
        border: 1px solid #e5e7eb;
        cursor: pointer;
        user-select: none;
    }

    .excluded 
    {
        background: rgba(198, 40, 40, 0.45);
    }

/* =============================================================== */
/* CLASS BLOCKS (classes drawn on the grid)                      */
/* =============================================================== */
    .class_block 
    {
    position: absolute;
    left: 2px;
    right: 2px;
    z-index: 1;
    box-sizing: border-box;
    background: #efefef;
    border-radius: 4px;
    padding: 0.3rem 0.4rem;
    overflow:hidden ;
    pointer-events: none;
    }

    .block_title 
    {
    margin: 0;
    font-size: 0.7rem;
    font-weight: 700;
    }

    .block_info 
    {
    margin: 0;
    font-size: 0.6rem;
    color: #6b7280;
    }

/* =============================================================== */
/* ONLINE CLASSES                                                */
/* =============================================================== */
    .calender_bottomtext h3
    {
        margin: 0;
        font-size: 1rem;
        white-space: nowrap;
       
    }

    .calender_bottomtext .sub1
    {
        margin: 0;
        padding-bottom: 10px;
        font-size: 0.65rem;
        font-weight: 600;
        color: #6b7280;
        white-space: nowrap;
    }

    .online_list 
    {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
  gap: 0.75rem;
  margin-top: 0.75rem;
    }

    .online_card 
    {
    background: #f4f4f4;
    border-radius: 6px;
    padding: 1rem;
    min-width: 0;
    max-width: 150px;
    margin-bottom: 0.5rem;
    margin-left: 0.5rem;
    }

    .online_card p 
    {
    margin: 0;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    }

    .online_code 
    {
    font-weight: 700;
    font-size: 0.95rem;
    }

    .online_text 
    {
    font-size: 0.85rem;
    color: #6b7280;
    margin-top: 0.2rem;
    }

/* =============================================================== */
/* SEARCH FILTERS                                                */
/* =============================================================== */
    .search_filters 
    {
        display: flex;
        flex-wrap: wrap;
        align-items: center;
        gap: 0.75rem;
        background: white;
        padding: 1rem;
        border-radius: 6px;
        margin-top: 1rem;
    }

        .search_filters input[type="text"],
    .search_filters label 
    {
        display: flex;
        align-items: center;
        gap: 0.4rem;
        background: #f4f4f4;
        border: 1px solid #e5e7eb;
        border-radius: 4px;
        padding: 0.5rem 0.75rem;
        font-size: 0.8rem;
        font-weight: 600;
    }

    .search_filters input[type="text"] 
    {
        font-weight: 400;
        min-width: 180px;
    }

    .search_filters select 
    {
        border: none;
        background: transparent;
        font-size: 0.8rem;
        font-weight: 400;
        cursor: pointer;
    }

    .search_filters .btn-red 
    {
        margin-left: auto;
    }

/* =============================================================== */
/* SEARCH RESULT CARDS                                           */
/* =============================================================== */
/* This is the section for the search results */
/* Need to fix width to match calender */

    .results 
    { 
        margin-top: 1rem; 
    }

    .results h3 
    { 
        margin: 0; 
        font-size: 1rem;
    }

    .cards 
    {
        display: grid;
        grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
        gap: 0.75rem;
    }

    .course-card 
    {
        display: flex;
        flex-direction: column;
        background: white;
        padding: 0.75rem;
        border-radius: 6px;
    }

    .meta {
        margin: 0;
        font-size: 0.7rem;
        font-weight: 600;
        color: #c62828;
    }

    .title {
        margin: 0.25rem 0 0.75rem;
        font-weight: 700;
        text-decoration: none;
        color: inherit;
    }

    .title:hover{
        color: #c62828
    }

    .course-card .btn-red 
    {
        margin-top: auto;
         width: 100%;
    }

/* =============================================================== */
/* SCHEDULE PLAN                                                 */
/* =============================================================== */
/* This is the section for the schedule plan */

    .plan_remove 
    {
        background: none;
        border: none;
        font-size: 1.2rem;
        color: #555;
        cursor: pointer;
    }

/* =============================================================== */
/* FAVORITES                                                     */
/* =============================================================== */
    .favorites 
    {
        background: white;
        padding: 1.25rem;
        border-radius: 6px;
        margin-top: 3rem;
    }

    .favorites h3 
    {   
        margin: 0 0 0.5rem;
        font-size: 1rem;
        color: #c62828;
    }

    .fav_label 
    {
        margin: 0 0 0.75rem;
        font-size: 0.75rem;
        font-weight: 700;
        color: #6b7280;
    }

    .fav_list 
    {  
        display: flex;
        flex-direction: column;
        gap: 0.75rem;
    }

    .fav_item 
    {
        display: flex;
        align-items: center;
        gap: 0.5rem;
    }

    .fav_row 
    {
        flex: 1;
        display: flex;
        justify-content: space-between;
        align-items: center;
        background: #f4f4f4;
        border-radius: 6px;
        padding: 0.5rem 0.75rem;
    }

    .fav_name 
    {
        margin: 0;
        font-weight: 700;
        font-size: 0.85rem;
    }
    

/* =============================================================== */
/* RESPONSIVE (keep last)                                        */
/* =============================================================== */
    @media (max-width: 900px) {
            .layout {
                grid-template-columns: 1fr;
            }
        }
</style>