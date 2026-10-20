
<script>  
    import { subjects } from '$lib/subjects.js';
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
        if (prereq) params.set('hasPreReq', 'true');

        loading = true;
        errorMsg = '';
        // This is the fetch request to the API to get the courses based on the filters
        try {
            const res = await fetch(`/api/courses?${params}`);
            const data = await res.json();
            if (res.ok) {
                results = data;
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
        <button class="btn-red">Favorite</button>

    </div>
    <div class="calender_scroll">
        <button class="btn-white"> &lt; </button> <p>Schedule</p> <!-- PLACE HOLDER var schedule need to change based on buttons and genrated number if schecules-->
        <button class="btn-white"> &gt; </button>
    </div>
    </div>
   
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
                ></div>
            {/each}
        {/each}
    </div>
    <div class="calender_bottomtext">
    <h3>Online Classes</h3>
    <p class="sub1">COURSES X</p> <!-- Variable needed for courses-->
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
      <option>All</option>
      <option>First Half</option>
      <option>Second Half</option>
      <option>Regular Full</option>
      <option>Special</option>
    </select>
  </label>

  <label>Mode:
    <select bind:value={mode}>
    <option value="All">All</option>
    <option value="in person">In Person</option>
    <option value="online">Online</option>
    <option value="hybrid">Hybrid</option>
    </select>
  </label>

  <label>Career:
    <select bind:value={career}>
      <option>All</option>
      <option>undergraduate</option>
      <option>graduate</option>
    </select>
  </label>

  <label><input type="checkbox" bind:checked={prereq} /> Pre-req needed</label>

  <button class="btn-red" onclick={applyFilters}>Apply Filters</button>

</section>

<!-- This is the section for the search results -->
<section class="results">
  <h3>Course Search Results</h3>
  <p class="hint">Click on red class to see details about class</p>

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
        <p class="meta">{course.course_code} • {course.course_session}</p>
        <p class="title">{course.course_name}</p>
        <button class="btn-red" onclick={() => addToPlan(course)}>
          Add to Schedule Plan
        </button>
      </div>
    {/each}
  </div>

</section>

</div>

<!-- This is the section for the schedule plan -->

<section class="schedule_plan">
  <h3>Schedule Plan</h3>
  <p class="sub1">Semester Draft</p>
  <p class="sub1">Pick classes and press generate different schedules.</p>

  <div class="stats">
    <div class="total_credits">
      <p class="stat_label">TOTAL CREDITS</p>
     
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
          <p class="plan_name">{course.course_name}</p>
        </div>
        <button class="plan_remove" onclick={() => removeFromPlan(course.course_code)}>⊗</button>
      </div>
    {/each}
  </div>

  <button class="btn-red generate">Generate</button>
</section>

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
        font-size: 0.8rem;
        color: #6b7280;
        padding: 0.25rem 0.5rem;
        height: 40px;
        box-sizing: border-box;
        border-left: 1px solid #e5e7eb;
        text-align: top;
        padding-left: 15px;
        
        
    }
    .cell
    {
        height:40px;
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

/* This is the section for the search results */

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

</style>