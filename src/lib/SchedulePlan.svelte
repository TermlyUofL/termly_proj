<script>
    // Props: data and functions that the PAGE passes in.
    //   plan        the list of courses in the plan
    //   onremove    function to call with a course code when ⊗ is clicked
    //   title       heading text (the course page uses 'Schedule Summary')
    //   ongenerate  optional: if given, a Generate button is shown
    //   generating  optional: true while a Generate request is running
    let {
        plan,
        onremove,
        title = 'Schedule Plan',
        ongenerate = null,
        generating = false
    } = $props();

    // Calculated from the plan, so it updates by itself when the plan changes.
    let totalCredits = $derived(plan.reduce((sum, c) => sum + (c.credit || 0), 0));

    // The distinct section types a course offers, like 'LEC, LAB'.
    function sectionTypes(course) {
        return [...new Set((course.sections || []).map(s => s.section_type))].join(', ');
    }

    // 'CSE350' -> 'CSE 350'
    function prettyCode(code) {
        return code.replace(/^([A-Za-z]+)(\d+)$/, '$1 $2');
    }
</script>

<section class="schedule_plan">
    <h3>{title}</h3>
    <p class="sub1">Semester Draft</p>
    {#if ongenerate}
        <p class="sub1">Pick classes and press generate different schedules.</p>
    {/if}

    <div class="stats">
        <div class="total_credits">
            <p class="stat_label">TOTAL CREDITS</p>
            <p class="stat_number red">{totalCredits}</p>
        </div>
        <div class="total_courses">
            <p class="stat_label">COURSES</p>
            <p class="stat_number">{plan.length}</p>
        </div>
    </div>

    <p class="list_label">ENROLLED COURSES ({plan.length})</p>

    <div class="course_list">
        {#each plan as course}
            <div class="plan_row">
                <div class="plan_text">
                    <p class="plan_code">{prettyCode(course.course_code)} {sectionTypes(course)}</p>
                    <p class="plan_name">{course.course_name} ({course.credit} cr)</p>
                </div>
                <button class="plan_remove" onclick={() => onremove(course.course_code)}>⊗</button>
            </div>
        {/each}
    </div>

    {#if ongenerate}
        <button class="btn-red generate" onclick={ongenerate} disabled={generating}>
            {generating ? 'Generating...' : 'Generate'}
        </button>
    {/if}
</section>

<style>
    .schedule_plan {
        background: white;
        padding: 1.25rem;
        border-radius: 6px;
    }

    .schedule_plan h3 {
        margin: 0 0 0.25rem;
        font-size: 1rem;
        font-weight: 700;
    }

    .schedule_plan .sub1 {
        margin: 0 0 0.25rem;
        font-size: 0.8rem;
        color: #6b7280;
    }

    .stats {
        display: grid;
        grid-template-columns: 1fr 1fr;
        gap: 0.75rem;
        margin: 1rem 0;
    }

    .total_credits,
    .total_courses {
        background: #f4f4f4;
        border-radius: 6px;
        padding: 0.75rem;
    }

    .stat_label {
        margin: 0;
        font-size: 0.7rem;
        font-weight: 700;
        color: #6b7280;
    }

    .stat_number {
        margin: 0.25rem 0 0;
        font-size: 1.6rem;
        font-weight: 800;
        color: #111;
    }

    .stat_number.red {
        color: #c62828;
    }

    .list_label {
        margin: 0 0 0.5rem;
        font-size: 0.75rem;
        font-weight: 700;
        color: #6b7280;
    }

    .course_list {
        display: flex;
        flex-direction: column;
        gap: 0.6rem;
    }

    .plan_row {
        display: flex;
        justify-content: space-between;
        align-items: center;
        background: #f4f4f4;
        border-radius: 6px;
        padding: 0.8rem;
    }

    /* removes the browser's default paragraph spacing inside each row */
    .plan_row p {
        margin: 0;
    }

    .plan_code {
        font-weight: 700;
        font-size: 0.85rem;
    }

    .plan_name {
        font-size: 0.75rem;
        color: #6b7280;
        margin-top: 0.2rem;
    }

    .plan_remove {
        background: none;
        border: none;
        font-size: 1.2rem;
        color: #555;
        cursor: pointer;
    }

    .plan_remove:hover {
        color: #c62828;
    }

    .generate {
        display: block;
        margin: 1rem auto 0;
    }

    /* the button style has to live here too, because styles are scoped */
    .btn-red {
        background: #c62828;
        color: white;
        border: none;
        padding: 0.6rem 1.2rem;
        border-radius: 4px;
        font-weight: 600;
        cursor: pointer;
    }

    .btn-red:hover {
        background: #a31f1f;
    }

    .btn-red:disabled {
        background: #9ca3af;
        cursor: default;
    }
</style>
