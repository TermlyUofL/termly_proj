
<script>  
    import { subjects } from '$lib/subjects.js';
    import { onMount } from 'svelte';
    // local storge 
    onMount(() => {
    applyFilters();
    });
// This is the script section for the calendar   
    const days = [ 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
    const hours = [ '7:00AM', '8:00AM', '9:00AM', '10:00AM', '11:00AM', '12:00PM', '1:00PM', '2:00PM', '3:00PM', '4:00PM', '5:00PM', '6:00PM', '7:00PM', '8:00PM'];
    
// This is the script section for the search filters
    let search = $state('');
    let subject = $state('All');
    let session = $state('All');
    let mode = $state('All');
    let career = $state('All');
    let prereq = $state(false);
    
    //function applyFilters() {
       // console.log({ q: search, subject, session, mode, career, prereq });
    //}
    let results = $state([]);
    let loading = $state(false);
    let errorMsg = $state('');

    
    
    // Thsi is function for applying the search filters and fetching the results from the API
    async function applyFilters() {
    const params = new URLSearchParams();
    if (search.trim()) params.set('q', search.trim());
    if (subject !== 'All') params.set('subject', subject);
    if (session !== 'All') params.set('session', session);
    if (mode !== 'All') params.set('mode', mode);
    if (career !== 'All') params.set('career', career);
    if (prereq) params.set('has_prereq', 'yes');          // changed

    loading = true;
    errorMsg = '';
    // This is the fetch request to the API to get the courses based on the filters
    try {
        const res = await fetch(`/api/courses?${params}`);
        const data = await res.json();
        if (res.ok) {
            results = data.courses;                        // changed
        } else {
            errorMsg = data.error;
            results = [];
        }
    } catch {
        errorMsg = 'Could not reach the server';
    }
    loading = false;
}

    
    let courses = $state([]);
    
    // This is functions for adding and removing courses from the schedule plan
    function addToPlan(course) {
        console.log('add', course.course_code);
        courses = [...courses, course];
    }
    function removeFromPlan(courseCode) {
        console.log('remove', courseCode);
        courses = courses.filter(c => c.course_code !== courseCode);
    }


    let excluded = $state({});
    let dragging = false;
    let paintValue = true;
// This is the functions for the calendar drag 
    function startDrag(day, hour) {
        const key = `${day}-${hour}`;
        paintValue = !excluded[key];   // first cell decides: paint red or erase
        dragging = true;
        excluded[key] = paintValue;
    }

    function dragOver(day, hour) {
        if (dragging) excluded[`${day}-${hour}`] = paintValue;
    }

    function stopDrag() {
    dragging = false;
    }

    function resetAll() {
    excluded = {};
    }

    function excludeAll() {
        const all = {};
        for (const day of days) {
            for (const hour of hours) {
                all[`${day}-${hour}`] = true;
        }
    }
    excluded = all;
    }


    const dayCode = { Monday: 'M', Tuesday: 'T', Wednesday: 'W', Thursday: 'Th', Friday: 'F' };

function hourNumber(label) {
    const [, h, , ap] = label.match(/(\d+):(\d+)(AM|PM)/);
    return (Number(h) % 12) + (ap === 'PM' ? 12 : 0);
}

function fmt(n) {
    return String(n).padStart(2, '0') + ':00';
}

function getExcludedTimes() {
    const out = [];
    for (const day of days) {
        let start = null;
        for (const hour of hours) {
            const isRed = excluded[`${day}-${hour}`];
            const n = hourNumber(hour);
            if (isRed && start === null) start = n;
            if (!isRed && start !== null) {
                out.push({ day: dayCode[day], start: fmt(start < 8 ? 0 : start), end: fmt(n) });
                start = null;
            }
        }
        if (start !== null) {
            const last = hourNumber(hours[hours.length - 1]);
            out.push({ day: dayCode[day], start: fmt(start < 8 ? 0 : start), end: fmt(last + 1) });
        }
    
    }
return out;
}

// ---- turn backend sections into calendar blocks ----
const dayNames = { M: 'Monday', T: 'Tuesday', W: 'Wednesday', R: 'Thursday', Tr: 'Thursday', Th: 'Thursday', F: 'Friday' };

// "M W F" -> ['Monday','Wednesday','Friday'],  "T Tr" -> ['Tuesday','Thursday']
function toDays(meetingDays) {
    const out = [];
    for (const token of meetingDays.split(/\s+/).filter(Boolean)) {
        if (token === 'TR') out.push('Tuesday', 'Thursday');
        else if (dayNames[token]) out.push(dayNames[token]);
    }
    return out;
}

// "14:20" -> 14.333
function toHours(t) {
    const [h, m] = t.split(':').map(Number);
    return h + m / 60;
}

// "14:20" -> "2:20 PM"
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

// ---- generated schedules ----
let schedules = $state([]);
let current = $state(0);
let problems = $state([]);
let generating = $state(false);

let currentSchedule = $derived(schedules[current] ?? null);
let schedule = $derived(currentSchedule ? currentSchedule.calendar.flatMap(sectionToBlocks) : []);
let onlineSections = $derived(currentSchedule ? currentSchedule.online : []);

function nextSchedule() {
    if (schedules.length) current = (current + 1) % schedules.length;
}

function prevSchedule() {
    if (schedules.length) current = (current - 1 + schedules.length) % schedules.length;
}

async function generateSchedules() {
    if (courses.length === 0) {
        problems = ['Add at least one course to the plan first.'];
        return;
    }

    generating = true;
    problems = [];
    schedules = [];          // clear the old result so a failure can't look like success
    current = 0;

    try {
        const body = {
            course_codes: courses.map(c => c.course_code),
            excluded_times: getExcludedTimes()
        };
        console.log('sending', body);

        const res = await fetch('/api/schedules/generate', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(body)
        });
        const data = await res.json();
        console.log('got', res.status, data);

        if (res.ok) {
            schedules = data.schedules;
            problems = data.problems;
        } else {
            problems = [data.error];
        }
    } catch (err) {
        console.log('generate failed', err);
        problems = ['Could not reach the server'];
    }

    generating = false;
}
    function blocksAt(day, hour) {
        return schedule.filter(b => b.day === day && Math.floor(b.start) === hourNumber(hour));
    }
    let totalCredits = $derived(courses.reduce((sum, c) => sum + (c.credit || 0), 0));
    let favorites = $state([]);
    let favCounter = 1;

    function addFavorite() {
        if (!currentSchedule) return;
        const key = currentSchedule.crns.join(',');
        if (favorites.some(f => f.key === key)) return;    // already saved
        favorites = [...favorites, { key, name: `Schedule${favCounter++}`, schedule: currentSchedule }];
    }

    function removeFavorite(key) {
        favorites = favorites.filter(f => f.key !== key);
    }

    function confirmFavorite(fav) {
        schedules = [fav.schedule];
        current = 0;
    }
    // ---- save and load (localStorage) ----
    let loaded = false;

    // runs once, when the page opens in the browser
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

        if (!loaded) return;
        localStorage.setItem('plan', planText);
        localStorage.setItem('excluded', excludedText);
        localStorage.setItem('favorites', favoritesText);
    });


</script>


<svelte:window onmouseup={stopDrag} />
<div class="layout">
<div class="main_col">
<!--This is the section for the calendar  -->
<section class="calendar_text"> <!-- This is the section for the calendar text -->
   
    <div class="calender_toptext"> 
    <div class="calender_lefttoptext">
    <h2> Weekly Schedule</h2>
    <p class="sub">Fall Semester</p>
    </div>
    
    <div class="calender_middletoptext">Click and drag to exclude times out of calendar. Click button to exclude all times.</div>
    
    <div class="calender_righttoptext">  
        <button class="btn-red" onclick={excludeAll}>Exclude all</button>
        <button class="btn-red" onclick={resetAll}>Reset</button>
        <button class="btn-red" onclick={addFavorite}>Favorite</button>

    </div>
    <div class="calender_scroll">
        <button class="btn-white" onclick={prevSchedule}>&lt;</button>
        <p>{schedules.length ? `Schedule ${current + 1} of ${schedules.length}` : 'No schedules'}</p>
        <button class="btn-white" onclick={nextSchedule}>&gt;</button>
    </div>
    
    </div>
    {#each problems as p}
    <p class="hint">
        {typeof p === 'string' ? p : `${p.course_code}: ${p.reason}`}
    </p>
    {/each} 
    <div class="calendar">  <!-- This is the calendar grid -->
        <div class="corner"></div> <!-- This is the corner cell -->
        {#each days as day}
            <div class="day">{day}</div>
        {/each}

    {#each hours as hour}
        <div class="hour">{hour}</div>
        {#each days as day}
        <!-- svelte-ignore a11y_no_static_element_interactions -->
        <div
            class="cell"
            class:excluded={excluded[`${day}-${hour}`]}
            onmousedown={() => startDrag(day, hour)}
            onmouseenter={() => dragOver(day, hour)}
        >
            {#each blocksAt(day, hour) as b}
                <div
                    class="class_block"
                    style="top: {(b.start % 1) * 100}%; height: {(b.end - b.start) * 100}%;"
                >
                    <p class="block_title">{b.code} – {b.name}</p>
                    <p class="block_info">{b.time}</p>
                    <p class="block_info">{b.room}</p>
                    <p class="block_info">{b.instructor}</p>
                </div>
            {/each}
        </div>
        {/each}
    {/each}
    </div>
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
 <input type="text" placeholder="Search courses..." bind:value={search} />

 <label>Subject:
  <select bind:value={subject}>
    <option value="All">All</option>
    {#each subjects as s}
      <option value={s.code}>{s.name} ({s.code})</option>
    {/each}
  </select>
 </label>

 <label>Session:
  <select bind:value={session}>
    <option value="All">All</option>
    <option value="First Half">First Half</option>
    <option value="Second Half">Second Half</option>
    <option value="Regular Full">Regular Full</option>
    <option value="Special">Special</option>
  </select>
</label>

  <label>Mode:
  <select bind:value={mode}>
    <option value="All">All</option>
    <option value="In Person">In Person</option>
    <option value="Online Asynchronous">Online Asynchronous</option>
    <option value="Online Synchronous">Online Synchronous</option>
  </select>
</label>

  <label>Career:
  <select bind:value={career}>
    <option value="All">All</option>
    <option value="Undergraduate">Undergraduate</option>
    <option value="Graduate">Graduate</option>
  </select>
</label>

  <label><input type="checkbox" bind:checked={prereq} /> Pre-req needed</label>

  <button class="btn-red" onclick={applyFilters}>Apply Filters</button>

</section>

<!-- This is the section for the search results -->
<section class="results">
  <h3>Course Search Results</h3>
  <p class="hint">Click on class name to see details about class</p>

  {#if loading}
    <p>Searching...</p>
  {:else if errorMsg}
    <p class="hint">{errorMsg}</p>
  {:else if results.length === 0}
    <p>No courses found.</p>
  {/if}

  <div class="cards">
    {#each results as course}
      <div class="course-card">
        <p class="meta">{course.course_code} • {course.credit} Credits</p>
        <a class="title" href="/course/{course.course_code}">{course.course_name}</a>
        <button class="btn-red" onclick={() => addToPlan(course)}>
          Add to Schedule Plan
        </button>
      </div>
    {/each}
  </div>

</section>

</div>

<!-- This is the section for the schedule plan -->
<div class="side_col">
<section class="schedule_plan">
  <h3>Schedule Plan</h3>
  <p class="sub1">Semester Draft</p>
  <p class="sub1">Pick classes and press generate different schedules.</p>

  <div class="stats">
    <div class="total_credits">
        <p class="stat_label">TOTAL CREDITS</p>
        <p class="stat_number red">{currentSchedule?.total_credits ?? 0}</p>
     
    </div>
    <div class="total_courses">
      <p class="stat_label">COURSES</p>
      <p class="stat_number">{courses.length}</p>
    </div>
  </div>

  <p class="list_label">COURSES ({courses.length})</p>

  <div class="course_list">
    {#each courses as course}
      <div class="plan_row">
        <div class="plan_text">
          <p class="plan_code">{course.course_code}</p>
          <p class="plan_name">{course.course_name} ({course.credit} cr)</p>
        </div>
        <button class="plan_remove" onclick={() => removeFromPlan(course.course_code)}>⊗</button>
      </div>
    {/each}
  </div>

  <button class="btn-red generate" onclick={generateSchedules} disabled={generating}>
    {generating ? 'Generating...' : 'Generate'}
</button>
</section>

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

    .corner{
        background-color: #e5e7e5;
        border-left: 1px solid #e5e7eb;
        border-top: 1px solid #e5e7eb;
    }
    .calendar_text
    {
        background-color: white;
        padding-left: rem;
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
    }
    .calender_middletoptext
    {
        max-width: 120px;
        max-height: 100px;
        text-align: center;
        margin-left: 2rem;
        color: #c62828;
    }
    .calendar_text .hint 
    {
    margin: 0.5rem 1rem;
    font-size: 0.85rem;
    }
    .calender_bottomtext h3
    {
        margin: 0;
        font-size: 1rem;
        white-space: nowrap;
       
    }
    .calender_bottomtext .sub1
    {
        margin: 0;
        font-size: 0.65rem;
        font-weight: 600;
        white-space: nowrap
    }
    .btn-red
    {
        background-color: #c62828;
        color: white;
        border: none;
        padding: 0.5rem 1rem;
        border-radius: 5px;
        cursor: pointer;
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
    p.sub
    {
        font-size: 0.8rem;
        color: #6b7280;
    }

    p.sub1
    {
        font-size: 0.8rem;
        color: #6b7280;
        padding-bottom: 10px;
        font-weight: bold;
        text-align: left;
    }

    .calendar
    {
        display: grid;
        grid-template-columns: 70px repeat(5, 1fr);
        border-bottom: 1px solid #e5e7eb;
        padding: 10px;
        padding-bottom: 10px;
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
        height: 80px;
        font-size: 0.8rem;
        color: #6b7280;
        padding: 0.25rem 0.5rem;
        height: 40px;
        box-sizing: border-box;
        border-left: 1px solid #e5e7eb;
        text-align: top;
        padding-left: 15px;
        
        
    }

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
    .cell
    {
        height:80px;
        position: relative;
        border-left: 1px solid #e5e7eb;
        border-top: 1px solid #e5e7eb;
        border-right: 1px solid #e5e7eb;
        border-bottom: 1px solid #e5e7eb;
        cursor: pointer;
        user-select: none;

    }
    .excluded 
    {
        background: rgba(198, 40, 40, 0.45);
    }

    .online_list {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
  gap: 0.75rem;
  margin-top: 0.75rem;
}

    .online_card {
    background: #f4f4f4;
    border-radius: 6px;
    padding: 1rem;
    min-width: 0;
    max-width: 150px;
    margin-bottom: 0.5rem;
    margin-left: 0.5rem;
    }

    .online_card p {
    margin: 0;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    }

    .online_code {
    font-weight: 700;
    font-size: 0.95rem;
    }

    .online_text {
    font-size: 0.85rem;
    color: #6b7280;
    margin-top: 0.2rem;
    }

/* This is the section for the search results */
/* Need to fix width to match calender */
    .results { 
        margin-top: 1rem; 
    }

    .results h3 
    { 
        margin: 0; 
        font-size: 1rem;
    }

    .hint {
        margin: 0.25rem 0 0.75rem;
        font-size: 0.75rem;
        color: #c62828;
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

/* This is the section for the schedule plan */
    .schedule_plan 
    {
    margin-top: 1rem;
    background: white;
    padding: 1.25rem;
    border-radius: 6px;
    }

    .schedule_plan h3 
    {
  margin: 0 0 0.5rem;
  font-size: 1rem;
    font-weight: 700;
    }

    .schedule_plan .sub1 
    {
  margin: 0 0 0.25rem;
  font-size: 0.8rem;
  color: #6b7280;
    }

    .stats 
    {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.75rem;
  margin: 1rem 0;
    }

    .total_credits,
    .total_courses 
    {
  background: #f4f4f4;
  border-radius: 6px;
  padding: 0.75rem;
    }

    .stat_label 
    {
  margin: 0;
  font-size: 0.7rem;
  font-weight: 700;
  color: #6b7280;
    }

    .stat_number 
    {
  margin: 0.25rem 0 0;
  font-size: 1.6rem;
  font-weight: 800;
  color: #111;
    }


    .list_label 
    {
  margin: 0 0 0.5rem;
  font-size: 0.75rem;
  font-weight: 700;
  color: #6b7280;
    }

    .course_list 
    {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
    }

    .plan_row 
    {
  display: flex;
  justify-content: space-between;
  align-items: center;
  background: #f4f4f4;
  border-radius: 6px;
  padding: 1rem;
    }

    .generate 
    {
  display: block;
  margin: 1rem auto 0;
    }

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

</style>