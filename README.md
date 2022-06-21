# Date Tools

Date tools are a light weight, extensible framework for simple period over period analysis in Looker. They can be extended on to any existing view with only minor updates to the existing views and explores.

# SQL

The included file uses Redshift SQL dialogue, but uses no redshift-specific functions, so it should be easily adaptable to any SQL dialect by modifying it to the dimensions to use the appropriate date functions.

# Features

 - User selectable start date for period over period analysis
 - Dynamically switch between trailing weeks, months, quarters, and years with a parameter
 - User selectable number of trailing periods
 - Calendar and relative date periods

# Quick-start

Include the date tools file in the file where your view is defined:

    include: "/Tools/date_tools.view.lkml"

Extend date tools on to the view you would like to add date tools to:

    view: my_view {
      extends: [date_tools]
      ...
    }

Add a hidden dimension to your view labeled **date_tools_date_field**.

This dimension must point to the **raw** date dimension in the view that you want to use for period over period analysis:

    view: my_view {
      extends: [date_tools]

      ### This is the dimension you need to add to your view:

      dimension: date_tools_date_field {
      hidden: yes
      sql: ${my_date_raw} ;;
      }

    ### And this is the existing time type dimension group in this view - it must contain the "raw" timeframe:

      dimension_group: my_date {
      view_label: "My Date"
      type: time
      description: "This is my date group that I want to use for period over period analysis."
      timeframes: [
        raw,
        time,
        date,
        day_of_week,
        week,
        month,
        quarter,
        year
      ]
      sql: ${TABLE}.my_date ;;
    }
      ...
    }

Finally, in your explore, add the following **sql_always_where** filter:

    explore: my_explore {
      label: "My Explore"

      sql_always_where: ${date_filter} ;;

    }

## Using the Date Tools

 1. Add the **Enable Date Tools?** parameter and set to **Yes**
 2. Add the **Period Type** parameter, and select either **Calendar** or **Relative**. The difference between calendar and relative is explained in detail below.
 3. *Optional:* Add the **Select Reference Date** parameter and select a reference date. For relative date periods, this is considered "Day 0". For calendar date periods, the period that contains this date is considered "Period 0". The default is one day before query run time if this parameter is not used.
 4. Add the **Select Timeframe** parameter and select an option - Days, months, quarters, or years.
 5. *Optional:* Add the **Trailing N Periods** parameter and select how many prior periods to return. The default is 1 if this parameter is not used.

## Year-over-year

Adding the **Enable Year over Year** parameter will retrieve data from the same window one full calendar year prior to the primary selected date period.

## Relative vs. Calendar Periods

**Relative** means the periods will begin at the selected date, and go back in time from there using fixed intervals - **7 days for a week, 30 days for a month, 90 days for a quarter, and 365 days for a year**. Ex: User selects period type 'weeks' and a 'reference date':
- Reference week will be between reference date and reference date - 7 days.
 - 1 week ago will be between reference date -8 days and reference date -14 days.
  - 2 weeks ago will be between reference date -15 days and reference date -21 days ...and so on.

**Calendar** uses the date_trunc() function to truncate to the month/week/year the user selects a date within. Ex: User selects reference date of 2022/02/15 (yyyymmdd)
- Reference month will be the *entire* month of February
- 1 month ago will be January 2022
- 3 Months ago will be December 2021
