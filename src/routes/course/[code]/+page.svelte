<script>
    // ===================================================================
    // IMPORTS
    // ===================================================================
    // This page shows the details of ONE course. Its address looks like
    // /course/CSE350; the folder name [code] tells SvelteKit that the last
    // part of the URL is a value we can read (page.params.code).
    // onMount:      runs code once the page has loaded in the browser.
    // page:         info about the current URL, including page.params.code.
    // SchedulePlan: the sidebar component that lists the courses in the plan.
    import { onMount } from 'svelte';
    import { page } from '$app/state';
    import SchedulePlan from '$lib/SchedulePlan.svelte';

    // ===================================================================
    // PAGE STATE
    // ===================================================================
    // $state(...) makes a variable reactive: when it changes, Svelte
    // re-draws any part of the page that uses it.
    // course:   the course details from the server (null until they arrive).
    // loading:  true while waiting for the server (shows "Loading...").
    // errorMsg: a message to show if loading the course failed.
    // plan:     the student's schedule plan. It is shared with the home page
    //           through localStorage, so both pages show the same plan.
    // loaded:   stays false until the saved plan has been read, so the save
    //           effect below doesn't overwrite it with an empty list first.
    //           It's a plain variable because nothing on screen uses it.
    let course = $state(null);
    let loading = $state(true);
    let errorMsg = $state('');
    let plan = $state([]);
    let loaded = false;

    // ===================================================================
    // DISPLAY HELPERS (turning server codes into readable text)
    // ===================================================================
    // The server uses short section types like "LEC". This maps them to
    // full words for the "Component" line.
    const typeNames = { LEC: 'Lecture', LAB: 'Lab', REC: 'Recitation', SEM: 'Seminar' };

    // Maps every day abbreviation the server might use to a short day name.
    // Different data spells Tuesday and Thursday in different ways.
    const shortNames = {
        M: 'Mon', T: 'Tue', W: 'Wed', R: 'Thu', F: 'Fri',
        Tu: 'Tue', Th: 'Thu', Tr: 'Thu'
    };

    // "M W F", "MWF", "T Tr" -> "Mon, Wed, Fri" / "Tue, Thu"
    // Splits the text on spaces, then pulls out each day code. The two-letter
    // codes (Tu, Th, Tr) come first in the regex so "Th" isn't read as "T".
    // new Set(...) removes duplicates, and join(', ') puts commas between.
    function dayLabel(meetingDays) {
        const out = [];
        for (const token of meetingDays.split(/\s+/).filter(Boolean)) {
            for (const part of token.match(/Tu|Th|Tr|[MTWRF]/g) || []) {
                out.push(shortNames[part]);
            }
        }
        return [...new Set(out)].join(', ');
    }

    // "14:20" -> "2:20 PM"
    // `h % 12 || 12` turns both 0 and 12 into 12 (for 12 AM and 12 PM).
    function fmtClock(t) {
        const [h, m] = t.split(':').map(Number);
        return `${h % 12 || 12}:${String(m).padStart(2, '0')} ${h >= 12 ? 'PM' : 'AM'}`;
    }

    // ===================================================================
    // LOADING THE PLAN AND THE COURSE
    // ===================================================================
    // Runs once when the page opens in the browser. onMount matters here:
    // SvelteKit also builds the page on the server, where localStorage
    // doesn't exist. `async` lets us `await` the server's answer.
    onMount(async () => {
        // 1. Load the saved plan. localStorage only stores text, so
        //    JSON.parse turns it back into a list.
        const saved = localStorage.getItem('plan');
        if (saved) plan = JSON.parse(saved);
        loaded = true;

        // 2. Ask the server for this course, using the code from the URL.
        //    res.ok is true when the server answered with a success status.
        try {
            const res = await fetch(`/api/courses/${page.params.code}`);
            const data = await res.json();
            if (res.ok) course = data;
            else errorMsg = data.error;
        } catch {
            // The request itself failed (e.g. server not running, no internet).
            errorMsg = 'Could not reach the server';
        }
        // Finished either way, so hide "Loading...".
        loading = false;
    });

    // ===================================================================
    // SAVING THE PLAN
    // ===================================================================
    // $effect runs once at the start, then again whenever a reactive value
    // it reads changes. Saving under the same 'plan' key as the home page
    // keeps both pages in sync.
    // save the plan whenever it changes
    $effect(() => {
        const text = JSON.stringify(plan);
        // `plan` is read ABOVE this line on purpose: Svelte only watches
        // values the effect actually reads, so reading it first makes the
        // effect re-run every time the plan changes.
        if (!loaded) return;
        localStorage.setItem('plan', text);
    });

    // ===================================================================
    // VALUES WORKED OUT FROM THE STATE
    // ===================================================================
    // $derived(...) values recalculate automatically when the things they
    // use change.
    // inPlan:       true if this course is already in the plan (used to
    //               disable the Add button and change its text).
    // totalCredits: the credits of every course in the plan added up
    //               (`|| 0` counts a missing value as 0).
    // components:   the different section types this course has, as
    //               readable text, e.g. "Lecture, Lab".
    let inPlan = $derived(course ? plan.some(c => c.course_code === course.course_code) : false);
    let totalCredits = $derived(plan.reduce((sum, c) => sum + (c.credit || 0), 0));
    let components = $derived(
        course ? [...new Set(course.sections.map(s => typeNames[s.section_type] || s.section_type))].join(', ') : ''
    );

    // ===================================================================
    // ADDING AND REMOVING COURSES
    // ===================================================================
    // "Add to Schedule Plan" button. Does nothing if the course hasn't
    // loaded yet or is already in the plan. [...plan, course] builds a new
    // list with the old courses plus this one.
    function addToPlan() {
        if (!course || inPlan) return;
        plan = [...plan, course];
    }

    // Keeps every course except the one with this code. Called by the
    // remove button in the SchedulePlan sidebar.
    function removeFromPlan(code) {
        plan = plan.filter(c => c.course_code !== code);
    }
</script>

<!-- Page layout: course details on the left, the schedule plan sidebar on the right. -->
<div class="layout">

    <!-- Main panel: back link, heading and the course details. -->
    <section class="detail">
        <!-- Link back to the home page (the calendar and search). -->
        <a class="back" href="/">‹ Back</a>
        <h2>Class Times</h2>
        <p class="sub">Fall Semester </p>

        <!-- Show one of: "Loading...", an error message, or the course itself. -->
        {#if loading}
            <p>Loading...</p>
        {:else if errorMsg}
            <p class="error">{errorMsg}</p>
        {:else if course}
            <div class="course_box">
                <!-- Top of the box: course name and basic info on the left, Add button on the right. -->
                <div class="course_top">
                    <div>
                        <h3>{course.course_code} - {course.course_name}</h3>
                        <p class="line">{course.credit}cr</p>
                        <p class="line">Session {course.course_session}</p>
                        <p class="line">Component: {components}</p>
                    </div>
                    <!-- Disabled (and relabelled) once the course is in the plan. -->
                    <button class="btn-red" onclick={addToPlan} disabled={inPlan}>
                        {inPlan ? 'In Schedule Plan' : 'Add to Schedule Plan'}
                    </button>
                </div>

                <!-- Description, plus a note if the course has a prerequisite. -->
                <p class="desc">
                    Description: {course.description}
                    {#if course.hasPreReq}<br />This course has a prerequisite.{/if}
                </p>

                <p class="avail">AVAILABLE TIMES</p>

                <!-- One row per section: days and times (or "Does Not Meet" for sections with no set time), instructor, location, and an Open/Full badge. -->
                {#each course.sections as s}
                <div class="time_row">
                    <div>
                        <p class="time_title">
                            {#if s.meeting_days}
                                {dayLabel(s.meeting_days)} - {fmtClock(s.start_time)} - {fmtClock(s.end_time)}
                            {:else}
                                Does Not Meet
                            {/if}
                        </p>
                        <p class="time_info">Instructor(s): {s.instructor_name || 'TBA'}</p>
                        {#if s.section_location}
                            <p class="time_info">Campus: {s.section_location}</p>
                        {:else if s.instruction_mode?.startsWith('Online')}
                            <p class="time_info">Campus: Online</p>
                        {/if}
                    </div>
                    <!-- class:full adds the "full" class (red badge) when the section is Full. -->
                    <span class="badge" class:full={s.status === 'Full'}>{s.status}</span>
                </div>
            {/each}
            </div>
        {/if}
    </section>

    <!-- Sidebar component, given a custom title, the plan, and a function to remove a course. -->
    <SchedulePlan title="Schedule Summary" plan={plan} onremove={removeFromPlan} />

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

/* =============================================================== */
/* PANELS                                                        */
/* =============================================================== */
    .detail, summary 
    {
        background: white;
        padding: 1.25rem;
        border-radius: 6px;
    }

/* =============================================================== */
/* BACK BUTTON, HEADINGS AND MESSAGES                            */
/* =============================================================== */
    .back 
    {
        display: inline-block;
        padding: 0.3rem 0.8rem;
        border: 1px solid #e5e7eb;
        border-radius: 4px;
        background: #f4f4f4;
        color: #111;
        text-decoration: none;
        font-size: 0.8rem;
        font-weight: 600;
    }

    h2 { margin: 1rem 0 0; font-size: 1.1rem; }
    .sub { margin: 0.2rem 0 1rem; font-size: 0.8rem; color: #6b7280; }
    .error { color: #c62828; }

/* =============================================================== */
/* COURSE BOX                                                    */
/* =============================================================== */
    .course_box 
    {
        border: 1px solid #c62828;
        border-radius: 6px;
        padding: 1rem;
    }

    .course_top 
    {
        display: flex;
        justify-content: space-between;
        align-items: flex-start;
        gap: 1rem;
    }

    h3 { margin: 0 0 0.25rem; font-size: 1rem; }
    .line { margin: 0.15rem 0; font-size: 0.8rem; color: #374151; }
    .desc { margin: 1rem 0; font-size: 0.8rem; color: #374151; }

/* =============================================================== */
/* AVAILABLE TIMES                                               */
/* =============================================================== */
    .avail { margin: 0 0 0.5rem; font-size: 0.7rem; font-weight: 700; color: #6b7280; }

    .time_row 
    {
        display: flex;
        justify-content: space-between;
        align-items: center;
        border: 1px solid #e5e7eb;
        border-radius: 4px;
        padding: 0.6rem 0.8rem;
        margin-bottom: 0.5rem;
    }

    .time_row:hover 
    {
        background: #fbeaea;
        border-color: #c62828;
    }

    .time_title { margin: 0 0 0.2rem; font-size: 0.85rem; font-weight: 700; }
    .time_info { margin: 0; font-size: 0.7rem; color: #6b7280; }

/* =============================================================== */
/* BADGES                                                        */
/* =============================================================== */
    .badge 
    {
        font-size: 0.65rem;
        font-weight: 700;
        padding: 0.15rem 0.5rem;
        border-radius: 4px;
        background: #dcfce7;
        color: #15803d;
    }

    .badge.full 
    {
        background: #fee2e2;
        color: #b91c1c;
    }

/* =============================================================== */
/* BUTTONS                                                       */
/* =============================================================== */
    .btn-red 
    {
        background: #c62828;
        color: white;
        border: none;
        padding: 0.6rem 1.2rem;
        border-radius: 4px;
        font-weight: 600;
        cursor: pointer;
        white-space: nowrap;
    }

    .btn-red:hover { background: #a31f1f; }
    .btn-red:disabled { background: #9ca3af; cursor: default; }

    .desc {
    white-space: pre-line;
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