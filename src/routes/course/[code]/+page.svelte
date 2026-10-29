<script>
    import { onMount } from 'svelte';
    import { page } from '$app/state';
    import SchedulePlan from '$lib/SchedulePlan.svelte';

    let course = $state(null);
    let loading = $state(true);
    let errorMsg = $state('');
    let plan = $state([]);
    let loaded = false;

    const typeNames = { LEC: 'Lecture', LAB: 'Lab', REC: 'Recitation', SEM: 'Seminar' };

    const shortNames = {
        M: 'Mon', T: 'Tue', W: 'Wed', R: 'Thu', F: 'Fri',
        Tu: 'Tue', Th: 'Thu', Tr: 'Thu'
    };

    // "M W F", "MWF", "T Tr" -> "Mon, Wed, Fri" / "Tue, Thu"
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
    function fmtClock(t) {
        const [h, m] = t.split(':').map(Number);
        return `${h % 12 || 12}:${String(m).padStart(2, '0')} ${h >= 12 ? 'PM' : 'AM'}`;
    }

    onMount(async () => {
        const saved = localStorage.getItem('plan');
        if (saved) plan = JSON.parse(saved);
        loaded = true;

        try {
            const res = await fetch(`/api/courses/${page.params.code}`);
            const data = await res.json();
            if (res.ok) course = data;
            else errorMsg = data.error;
        } catch {
            errorMsg = 'Could not reach the server';
        }
        loading = false;
    });

    // save the plan whenever it changes
    $effect(() => {
        const text = JSON.stringify(plan);
        if (!loaded) return;
        localStorage.setItem('plan', text);
    });

    let inPlan = $derived(course ? plan.some(c => c.course_code === course.course_code) : false);
    let totalCredits = $derived(plan.reduce((sum, c) => sum + (c.credit || 0), 0));
    let components = $derived(
        course ? [...new Set(course.sections.map(s => typeNames[s.section_type] || s.section_type))].join(', ') : ''
    );

    function addToPlan() {
        if (!course || inPlan) return;
        plan = [...plan, course];
    }

    function removeFromPlan(code) {
        plan = plan.filter(c => c.course_code !== code);
    }
</script>

<div class="layout">

    <section class="detail">
        <a class="back" href="/">‹ Back</a>
        <h2>Class Times</h2>
        <p class="sub">Fall Semester </p>

        {#if loading}
            <p>Loading...</p>
        {:else if errorMsg}
            <p class="error">{errorMsg}</p>
        {:else if course}
            <div class="course_box">
                <div class="course_top">
                    <div>
                        <h3>{course.course_code} - {course.course_name}</h3>
                        <p class="line">{course.credit}cr</p>
                        <p class="line">Session {course.course_session}</p>
                        <p class="line">Component: {components}</p>
                    </div>
                    <button class="btn-red" onclick={addToPlan} disabled={inPlan}>
                        {inPlan ? 'In Schedule Plan' : 'Add to Schedule Plan'}
                    </button>
                </div>

                <p class="desc">
                    Description: {course.description}
                    {#if course.hasPreReq}<br />This course has a prerequisite.{/if}
                </p>

                <p class="avail">AVAILABLE TIMES</p>

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
                            <p class="time_info">Location: {s.section_location || 'TBA'}</p>
                        </div>
                        <span class="badge" class:full={s.status === 'Full'}>{s.status}</span>
                    </div>
                {/each}
            </div>
        {/if}
    </section>

    <SchedulePlan title="Schedule Summary" plan={plan} onremove={removeFromPlan} />

</div>

<style>
    .layout 
    {
        display: grid;
        grid-template-columns: 1fr 320px;
        gap: 1rem;
        align-items: start;
    }

    .detail, summary 
    {
        background: white;
        padding: 1.25rem;
        border-radius: 6px;
    }

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
    h3 { margin: 0 0 0.25rem; font-size: 1rem; }
    .sub { margin: 0.2rem 0 1rem; font-size: 0.8rem; color: #6b7280; }
    .error { color: #c62828; }

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

    .line { margin: 0.15rem 0; font-size: 0.8rem; color: #374151; }
    .desc { margin: 1rem 0; font-size: 0.8rem; color: #374151; }
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

    @media (max-width: 900px) {
    .layout {
        grid-template-columns: 1fr;
    }
}
</style>