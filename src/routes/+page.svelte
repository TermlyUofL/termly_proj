<script>    
    const days = [ 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
    const hours = [ '7:00AM', '8:00AM', '9:00AM', '10:00AM', '11:00AM', '12:00PM', '1:00PM', '2:00PM', '3:00PM', '4:00PM', '5:00PM', '6:00PM', '7:00PM', '8:00PM'];
</script>

<section class="calendar_text"> <!-- This is the section for the calendar text -->
   
    <div class="calender_toptext"> 
    <div class="calender_lefttoptext">
    <h2> Weekly Schedule</h2>
    <p class="sub">Fall Semester</p>
    </div>
    
    <div class="calender_middletoptext">Click and drag to exclude times out of calendar. Click button to exclude all times.</div>
    
    <div class="calender_righttoptext">  
        <button class="btn-red">Exclude all</button>
        <button class="btn-red">Reset</button>
        <button class="btn-red">Favorite</button>

    </div>
    <div class="calender_scroll">
        <button class="btn-white"> &lt </button> Schedule <!-- PLACE HOLDER var schedule need to change based on buttons and genrated number if schecules-->
        <button class="btn-white"> &gt </button>
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
            <div class="cell"></div>
        {/each}
    {/each}
    <h3>Online Classes</h3>
    <p class="sub1">COURSES X</p> <!-- Variable needed for courses-->

    
        
    </div>
</section>

<style>
    .corner{
        background-color: #e5e7e5;
        border-left: 1px solid #e5e7eb;
        border-top: 1px solid #e5e7eb;
    }
    .calendar_text{
        background-color: white;
        padding-left: rem;
        
    }
    .calender_toptext{
        display: flex;
        justify-content: space-between;
        align-items: center;
        
    }
    .calender_lefttoptext{
        max-width: 150px;
        max-height: 100px;

    }
    .calender_middletoptext{
        max-width: 150px;
        max-height: 100px;
        text-align: center;
        color: #c62828;
    }
    .btn-red{
        background-color: #c62828;
        color: white;
        border: none;
        padding: 0.5rem 1rem;
        border-radius: 5px;
        cursor: pointer;
    }
    .calender_scroll{
        display: flex;
        align-items: center;
        gap: 1rem;
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
    p.sub{
        font-size: 0.8rem;
        color: #6b7280;
    }

    p.sub1{
        font-size: 0.8rem;
        color: #6b7280;
        padding-bottom: 10px;
        font-weight: bold;
        text-align: left;
    }

    .calendar{
        display: grid;
        grid-template-columns: 70px repeat(5, 1fr);
        border-bottom: 1px solid #e5e7eb;
        padding: 10px;
        padding-bottom: 10px;
    }
    .day{
        text-align: center;
        font-weight: bold;
        padding: 10px;
        background-color: #e5e7e5;
        border-left: 1px solid rgb(202, 190, 190);
        border-top: 1px solid rgb(202, 190, 190);
    }
    .hour{
        font-size: 0.8rem;
        color: #6b7280;
        padding: 0.25rem 0.5rem;
        height: 40px;
        box-sizing: border-box;
        border-left: 1px solid #e5e7eb;
        text-align: top;
        padding-left: 15px;
        
        
    }
    .cell{
        height:40px;
        border-left: 1px solid #e5e7eb;
        border-top: 1px solid #e5e7eb;
        border-right: 1px solid #e5e7eb;
        border-bottom: 1px solid #e5e7eb;
    }
</style>