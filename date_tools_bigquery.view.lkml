## Wait, don't panic! This view looks massive, but it purposefully uses a lot of helper dimensions to calculate date ranges. Almost all of these helper
## dimensions are hidden from the user. This view could be condensed down to a fraction of the size using one-liner nested date_diff/date_trunc/date_add functions,
## but that would make it a harder to understand. Making heavy use of Looker's substitution syntax makes updating and debugging a lot easier.

view: date_tools {
  extension: required

  ## This defines the date field used in the table. Date is actually a bit of a misnomer - this is expected to be a timestamp type column.
  ## To define this, you just need to create a dimension called "date_tools_date_field" in the view this is being extended onto.

  ## Current Timestamp is also used as the default "analysis date" - meaning the date from which relative time periods are defined from.

  dimension_group: date_field {
    type: time
    sql: ${date_tools_date_field} ;;
    hidden: yes
    view_label: "_Date Tools"
  }

  dimension_group: current_timestamp {
    type: time
    sql: current_timestamp() ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  ## BEGIN PARAMETERS - these are the parameters a user can select in order to retrieve their desired relative date range.

  parameter: enable_date_tools {
    type: unquoted
    allowed_value: {
      value: "yes"
      label: "Yes"
    }
    allowed_value: {
      value: "no"
      label: "No"
    }
    view_label: "_Date Tools"
    hidden: no
  }

  parameter: compare_to_last_year {
    type: unquoted
    allowed_value: {
      value: "yes"
      label: "Yes"
    }
    allowed_value: {
      value: "no"
      label: "No"
    }
    view_label: "_Date Tools"
    hidden: no
  }

  ##  allows a user to select a reference date if they want to do a period over period analysis starting on a past date, rather than the current date

  parameter: select_reference_date {
    type: date_time
    convert_tz: no
    view_label: "_Date Tools"
    hidden: no
  }

  ## allows a user to select a custom period length - for example, selecting 45 would give the user a time period that ends at the reference date,
  ## and starts 45 days prior to that.

  parameter: custom_period_length {
    type: number
    view_label: "_Date Tools"
    hidden: no
  }

  ## allows a user to decide whether they want the analysis to be DOW aligned or not. DOW aligned meams that a Monday will always be compared to a Monday,
  ## a Tuesday to a Tuesday, and so on. This is a common need in things like eCommerce analysis, as traffic and purchasing behaviour is often heavily
  ## correlated to day of week.

  parameter: dow_aligned {
    type: unquoted
    allowed_value: {
      value: "yes"
      label: "Yes"
    }
    allowed_value: {
      value: "No"
      label: "no"
    }
    view_label: "_Date Tools"
    hidden: no
  }

  ## the period the user wants to analyze.

  parameter: analysis_period {
    type: unquoted
    allowed_value: {
      value: "wtd"
      label: "Week-to-Date"
    }
    allowed_value: {
      value: "mtd"
      label: "Month-to-Date"
    }
    allowed_value: {
      value: "qtd"
      label: "Quarter-to-Date"
    }
    allowed_value: {
      value: "ytd"
      label: "Year-to-Date"
    }
    allowed_value: {
      value: "lw"
      label: "Last Week"
    }
    allowed_value: {
      value: "lm"
      label: "Last Month"
    }
    allowed_value: {
      value: "lq"
      label: "Last Quarter"
    }
    allowed_value: {
      value: "ly"
      label: "Last Year"
    }
    allowed_value: {
      value: "custom"
      label: "Custom Period"
    }
    view_label: "_Date Tools"
    hidden: no
  }

  parameter: trailing_periods {
    type: number
    view_label: "_Date Tools"
    hidden: no
  }

  ### END PARAMETERS

  ### BEGIN UNHIDDEN DATE DIMENSIONS - these are relative date fields that are useful in reporting.


  dimension: relative_day {
    type: number
    sql:

    case
      when ${relative_year} = "This Year" then date_diff(${end_ty}, ${date_field_date}, day)
      when ${relative_year} = "Last Year" then date_diff(${end_ly}, ${date_field_date}, day)
      else null
    end

    ;;
    view_label: "_Date Tools"
    label: "Days Ago"
    hidden: no
    value_format_name: decimal_0
  }

  dimension: relative_week {
    type: number
    sql:

    floor(

    (${relative_day} - date_diff(${wtd_end_ty}, date_trunc(${analysis_date_date}, week), day)) / 7) + 1

    ;;
    view_label: "_Date Tools"
    label: "Weeks Ago"
    hidden: no
    value_format_name: decimal_0
  }

  dimension: relative_custom_period {
    type: number
    sql:

    floor(

    ${relative_day} / {{ custom_period_length._parameter_value }}) --+ 1
    ;;

    view_label: "_Date Tools"
    label: "Custom Periods Ago"
    hidden: no
    value_format_name: decimal_0
  }

  dimension: relative_year {
    type: string
    sql:

    case
      when ${ty_date_filter} then "This Year"
      when ${ly_date_filter} then "Last Year"
    end

    ;;
    view_label: "_Date Tools"
    hidden: no
  }

  ### END UNHIDDEN DATE DIMENSIONS


  ## BEGIN DOW Aligned Helper Dimensions - these dims are all used to figure out a DOW aligned equivalent to a given date for prior year using ISO weeks/years.
  ## This could all be done in a one-liner SQL function, but it gets sort of obtuse. It's easier to understand what's going on if you take advantage
  ## of Looker's substitution syntax, and let the Looker SQL engine worry about generating the mess of nested date conversion functions.

  dimension: first_day_iso_year {
    sql: date_trunc(${analysis_date_date}, isoyear) ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  dimension: last_day_last_iso_year {
    sql: date_add(${first_day_iso_year}, interval -1 day) ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  dimension: first_day_last_iso_year {
    sql: date_trunc(${last_day_last_iso_year}, isoyear) ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  dimension: current_iso_week {
    sql: extract(isoweek from ${analysis_date_date}) ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  dimension: current_day_of_week {
    sql: extract(dayofweek from ${analysis_date_date}) ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  dimension: iso_day_of_week {
    sql: if(${current_day_of_week}=1, 7, ${current_day_of_week}-1);;
    view_label: "_Date Tools"
    hidden: yes
  }

  ### END DOW ALIGNED HELPER DIMENSIONS

  ## BEGIN Last-Period DOW Aligned Helper Dimensions - these do the same as the above, but are used for calculating the end date for last year when selecting a
  ## "last _____" time period for analysis.

  ## You'll see heavy use of Liquid conditional statements throughout this view. The important thing to remember with these is that they are rendered
  ## prior to the query being run - so the query that is submitted to BQ will actually change based on the parameter options selected.

  dimension_group: lp_analysis_date {
    type: time
    sql:

    {% if analysis_period._parameter_value == 'lm' %}

    ${lm_end_ty}

    {% elsif analysis_period._parameter_value == 'lq' %}

    ${lq_end_ty}

    {% elsif analysis_period._parameter_value == 'ly' %}

    ${ly_end_ty}

    {% else %}

    null

    {% endif %}

    ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  dimension: first_day_iso_year_lp {
    sql: date_trunc(${lp_analysis_date_date}, isoyear) ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  dimension: last_day_last_iso_year_lp {
    sql: date_add(${first_day_iso_year_lp}, interval -1 day) ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  dimension: first_day_last_iso_year_lp {
    sql: date_trunc(${last_day_last_iso_year_lp}, isoyear) ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  dimension: current_iso_week_lp {
    sql: extract(isoweek from ${lp_analysis_date_date}) ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  dimension: current_day_of_week_lp {
    sql: extract(dayofweek from ${lp_analysis_date_date}) ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  dimension: iso_day_of_week_lp {
    sql: if(${current_day_of_week_lp}=1, 7, ${current_day_of_week_lp}-1);;
    view_label: "_Date Tools"
    hidden: yes
  }

  dimension_group: same_day_last_year_dow_aligned_lp {
    type: time
    sql: date_add(date_add(${first_day_last_iso_year_lp}, interval (${current_iso_week_lp}-1) week), interval ${iso_day_of_week_lp}-1 day) ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  ### END Last-Period DOW Aligned Helper Dimensions

  ## Analysis date is the starting point for determing end date. For a "to-date" analysis, this is the end date.
  ## However, for an analysis like last month, last week, etc, this is used as a starting point, and further date trunc functions are used to figure out end date.

  dimension_group: analysis_date {
    type: time
    sql:

    {% if select_reference_date._is_filtered %}

    {% parameter select_reference_date %}

    {% else %}

    ${current_timestamp_date}

    {% endif %} ;;

    view_label: "_Date Tools"
    hidden: yes
  }

  ## same day last year

  dimension_group: same_day_last_year_dow_aligned {
    type: time
    sql: date_add(date_add(${first_day_last_iso_year}, interval (${current_iso_week}-1) week), interval ${iso_day_of_week}-1 day) ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  dimension_group: same_day_last_year {
    type: time
    sql: date_add(${analysis_date_date}, interval -1 year) ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  ## to date analysis helper dimensions


  dimension_group: same_day_last_year_dynamic {
    type: time
    sql:

    {% if dow_aligned._parameter_value == "yes" %}

    ${same_day_last_year_dow_aligned_date}

    {% else %}

    ${same_day_last_year_date}

    {% endif %}

    ;;
    view_label: "_Date Tools"
    hidden: yes

  }

  ### BEGIN: Calculation of start/end dates for different relative date periods. These will be passed to the final date filter used to actually filter the data
  ### in the where clause. Which set of filters is selected depends on what the user has selected for options.

  ## wtd

  dimension: days_into_week {
    sql: date_diff(${wtd_end_ty}, ${wtd_start_ty}, day) ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  dimension: wtd_end_ty {
    sql: ${analysis_date_date} ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  dimension: wtd_start_ty {
    sql: date_add(date_trunc(${analysis_date_date}, week), interval (-1*{{ trailing_periods._parameter_value }}) week) ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  dimension: wtd_end_ly {
    sql: ${same_day_last_year_dynamic_date} ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  dimension: wtd_start_ly {
    sql: date_add(${wtd_end_ly}, interval (-1*${days_into_week}) day) ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  ## mtd

  dimension: days_into_month {
    sql: date_diff(${mtd_end_ty}, ${mtd_start_ty}, day) ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  dimension: mtd_end_ty {
    sql: ${analysis_date_date} ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  dimension: mtd_start_ty {
    sql: date_add(date_trunc(${analysis_date_date}, month), interval (-1*{{ trailing_periods._parameter_value }}) month) ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  dimension: mtd_end_ly {
    sql: ${same_day_last_year_dynamic_date} ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  dimension: mtd_start_ly {
    sql: date_add(${mtd_end_ly}, interval (-1*${days_into_month}) day) ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  ## qtd

  dimension: days_into_quarter {
    sql: date_diff(${qtd_end_ty}, ${qtd_start_ty}, day) ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  dimension: qtd_end_ty {
    sql: ${analysis_date_date} ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  dimension: qtd_start_ty {
    sql: date_add(date_trunc(${analysis_date_date}, quarter), interval (-1*{{ trailing_periods._parameter_value }}) quarter) ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  dimension: qtd_end_ly {
    sql: ${same_day_last_year_dynamic_date} ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  dimension: qtd_start_ly {
    sql: date_add(${qtd_end_ly}, interval (-1*${days_into_quarter}) day) ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  ## ytd

  dimension: days_into_year {
    sql: date_diff(${ytd_end_ty}, ${ytd_start_ty}, day) ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  dimension: ytd_end_ty {
    sql: ${analysis_date_date} ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  dimension: ytd_start_ty {
    sql: date_add(date_trunc(${analysis_date_date}, year), interval (-1*{{ trailing_periods._parameter_value }}) year) ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  dimension: ytd_end_ly {
    sql: ${same_day_last_year_dynamic_date} ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  dimension: ytd_start_ly {
    sql: date_add(${ytd_end_ly}, interval (-1*${days_into_year}) day) ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  ## lw

  dimension: lw_start_ty {
    sql: date_add(date_trunc(date_add(${analysis_date_date}, interval -1 week), week), interval (-1*{{ trailing_periods._parameter_value }}) week) ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  dimension: lw_end_ty {
    sql: date_add(date_trunc(${analysis_date_date}, week), interval -1 day) ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  dimension: lw_start_ly {
    sql:

    {% if dow_aligned._parameter_value == "yes" %}

    date_add(date_trunc(date_add(${same_day_last_year_dynamic_date}, interval -1 week), week), interval (-1*{{ trailing_periods._parameter_value }}) week)

    {% else %}

    date_add(${lw_start_ty}, interval -1 year)

    {% endif %}

    ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  dimension: lw_end_ly {
    sql:

    {% if dow_aligned._parameter_value == "yes" %}

    date_add(date_trunc(${same_day_last_year_dynamic_date}, week), interval -1 day)

    {% else %}

    date_add(${lw_end_ty}, interval -1 year)

    {% endif %} ;;


    view_label: "_Date Tools"
    hidden: yes
  }

  ## lm

  dimension: lm_start_ty {
    sql: date_add(date_trunc(date_add(${analysis_date_date}, interval -1 month), month), interval (-1*{{ trailing_periods._parameter_value }}) month) ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  dimension: lm_end_ty {
    sql: date_add(date_trunc(${analysis_date_date}, month), interval -1 day) ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  dimension: month_duration {
    sql: date_diff(${lm_end_ty}, ${lm_start_ty}, day) ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  dimension: lm_start_ly {
    sql:

    {% if dow_aligned._parameter_value == 'yes' %}

    date_add(date_add(${lm_end_ly}, interval (-1*${month_duration}) day), interval (-1*{{ trailing_periods._parameter_value }}) month)

    {% else %}

    date_add(${lm_start_ty}, interval -1 year)

    {% endif %}

    ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  dimension: lm_end_ly {
    sql:

    {% if dow_aligned._parameter_value == 'yes' %}

    ${same_day_last_year_dow_aligned_lp_date}

    {% else %}

    date_add(${lm_end_ty}, interval -1 year)

    {% endif %};;

    view_label: "_Date Tools"
    hidden: yes
    }

  ## lq

  dimension: lq_start_ty {
    sql: date_add(date_trunc(date_add(${analysis_date_date}, interval -1 quarter), quarter), interval (-1*{{ trailing_periods._parameter_value }}) quarter) ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  dimension: lq_end_ty {
    sql: date_add(date_trunc(${analysis_date_date}, quarter), interval -1 day) ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  dimension: quarter_duration {
    sql: date_diff(${lq_end_ty}, ${lq_start_ty}, day) ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  dimension: lq_start_ly {
    sql:

    {% if dow_aligned._parameter_value == 'yes' %}

    date_add(date_add(${lq_end_ly}, interval (-1*${quarter_duration}) day), interval (-1*{{ trailing_periods._parameter_value }}) quarter)

    {% else %}

    date_add(${lq_start_ty}, interval -1 year)

    {% endif %}

      ;;
    view_label: "_Date Tools"
    hidden: yes
  }
  dimension: lq_end_ly {
    sql:

    {% if dow_aligned._parameter_value == 'yes' %}

    ${same_day_last_year_dow_aligned_lp_date}

    {% else %}

    date_add(${lq_end_ty}, interval -1 year)

    {% endif %};;


    view_label: "_Date Tools"
    hidden: yes
  }

  ## ly

  dimension: ly_start_ty {
    sql: date_add(date_trunc(date_add(${analysis_date_date}, interval -1 year), year), interval (-1*{{ trailing_periods._parameter_value }}) year) ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  dimension: ly_end_ty {
    sql: date_add(date_trunc(${analysis_date_date}, year), interval -1 day) ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  dimension: year_duration {
    sql: 365 ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  dimension: ly_start_ly {
    sql:

    {% if dow_aligned._parameter_value == 'yes' %}

    date_add(date_add(${ly_end_ly}, interval (-1*${year_duration}) day), interval (-1*{{ trailing_periods._parameter_value }}) year)


    {% else %}

    date_add(${ly_start_ty}, interval -1 year)

    {% endif %}

    ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  dimension: ly_end_ly {
    sql:

    {% if dow_aligned._parameter_value == 'yes' %}

    ${same_day_last_year_dow_aligned_lp_date}

    {% else %}

    date_add(${ly_end_ty}, interval -1 year)

    {% endif %};;

    view_label: "_Date Tools"
    hidden: yes
  }

  ## custom date range



  dimension: custom_start_ty {
    sql: date_add(date_add(${analysis_date_date}, interval (-1*${custom_duration}) day), interval (-1 * {{ trailing_periods._parameter_value }} * {{ custom_period_length._parameter_value }} ) day) ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  dimension: custom_end_ty {
    sql: ${analysis_date_date} ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  dimension: custom_duration {
    sql: ({{ custom_period_length._parameter_value }}-1) ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  dimension: custom_start_ly {
    sql:

    date_add(date_add(${custom_end_ly}, interval (-1*${custom_duration}) day), interval (-1 * {{ trailing_periods._parameter_value }} * {{ custom_period_length._parameter_value }} ) day)

    ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  dimension: custom_end_ly {
    sql:

    {% if dow_aligned._parameter_value == 'yes' %}

    ${same_day_last_year_dow_aligned_date}

    {% else %}

    date_add(${custom_end_ty}, interval -1 year)

    {% endif %};;

    view_label: "_Date Tools"
    hidden: yes
  }

  ### FILTER DIMENSIONS - these are used to build a WHERE clause for the SQL query. Liquid is again used here to decide which dimensions to filter on.

  dimension: start_ty {
    sql:

    {% if analysis_period._parameter_value == 'wtd' %}

    ${wtd_start_ty}

    {% elsif analysis_period._parameter_value == 'mtd' %}

    ${mtd_start_ty}

    {% elsif analysis_period._parameter_value == 'qtd' %}

    ${qtd_start_ty}

    {% elsif analysis_period._parameter_value == 'ytd' %}

    ${ytd_start_ty}

    {% elsif analysis_period._parameter_value == 'lw' %}

    ${lw_start_ty}

    {% elsif analysis_period._parameter_value == 'lm' %}

    ${lm_start_ty}

    {% elsif analysis_period._parameter_value == 'lq' %}

    ${lq_start_ty}

    {% elsif analysis_period._parameter_value == 'ly' %}

    ${ly_start_ty}

    {% elsif analysis_period._parameter_value == 'custom' %}

    ${custom_start_ty}

    {% endif %}

    ;;
    view_label: "_Date Tools"
    hidden: yes
  }

  dimension: start_ly {
    sql:

    {% if analysis_period._parameter_value == 'wtd' %}

    ${wtd_start_ly}

    {% elsif analysis_period._parameter_value == 'mtd' %}

    ${mtd_start_ly}

    {% elsif analysis_period._parameter_value == 'qtd' %}

    ${qtd_start_ly}

    {% elsif analysis_period._parameter_value == 'ytd' %}

    ${ytd_start_ly}

    {% elsif analysis_period._parameter_value == 'lw' %}

    ${lw_start_ly}

    {% elsif analysis_period._parameter_value == 'lm' %}

    ${lm_start_ly}

    {% elsif analysis_period._parameter_value == 'lq' %}

    ${lq_start_ly}

    {% elsif analysis_period._parameter_value == 'ly' %}

    ${ly_start_ly}

    {% elsif analysis_period._parameter_value == 'custom' %}

    ${custom_start_ly}

    {% endif %}

    ;;

    view_label: "_Date Tools"
    hidden: yes
  }

  ##

  dimension: end_ty {
    sql:

    {% if analysis_period._parameter_value == 'wtd' %}

    ${wtd_end_ty}

    {% elsif analysis_period._parameter_value == 'mtd' %}

    ${mtd_end_ty}

    {% elsif analysis_period._parameter_value == 'qtd' %}

    ${qtd_end_ty}

    {% elsif analysis_period._parameter_value == 'ytd' %}

    ${ytd_end_ty}

    {% elsif analysis_period._parameter_value == 'lw' %}

    ${lw_end_ty}

    {% elsif analysis_period._parameter_value == 'lm' %}

    ${lm_end_ty}

    {% elsif analysis_period._parameter_value == 'lq' %}

    ${lq_end_ty}

    {% elsif analysis_period._parameter_value == 'ly' %}

    ${ly_end_ty}

    {% elsif analysis_period._parameter_value == 'custom' %}

    ${custom_end_ty}

    {% endif %}


    ;;

    view_label: "_Date Tools"
    hidden: yes
  }

  dimension: end_ly {
    sql:

    {% if analysis_period._parameter_value == 'wtd' %}

    ${wtd_end_ly}

    {% elsif analysis_period._parameter_value == 'mtd' %}

    ${mtd_end_ly}

    {% elsif analysis_period._parameter_value == 'qtd' %}

    ${qtd_end_ly}

    {% elsif analysis_period._parameter_value == 'ytd' %}

    ${ytd_end_ly}

    {% elsif analysis_period._parameter_value == 'lw' %}

    ${lw_end_ly}

    {% elsif analysis_period._parameter_value == 'lm' %}

    ${lm_end_ly}

    {% elsif analysis_period._parameter_value == 'lq' %}

    ${lq_end_ly}

    {% elsif analysis_period._parameter_value == 'ly' %}

    ${ly_end_ly}

    {% elsif analysis_period._parameter_value == 'custom' %}

    ${custom_end_ly}

    {% endif %}

    ;;

    view_label: "_Date Tools"
    hidden: yes
  }

  ### FINAL DATE FILTER
  ### This is what it all comes down to. Everything above is simply used to populate this date filter. We're explicitly filtering the data retrieved which has
  ### some significant advantages to some other period over period techniques in BigQuery - most notably, partition culling works to limit query sizes
  ### as expected.

  dimension: ty_date_filter {
    sql: ( ${date_field_date} >= ${start_ty} and ${date_field_date} <= ${end_ty} ) ;;
    hidden: yes
    view_label: "_Date Tools"
  }

  dimension: ly_date_filter {
    sql: ( ${date_field_date} >= ${start_ly} and ${date_field_date} <= ${end_ly} ) ;;
    hidden: yes
    view_label: "_Date Tools"
  }

  dimension: date_filter {
    sql:

    {% if enable_date_tools._parameter_value == 'yes' %}

    ${ty_date_filter}

      {% if compare_to_last_year._parameter_value == 'yes' %}

      OR

      ${ly_date_filter}

      {% else %}

      --no YOY filter

      {% endif %}

    {% else %}

    --no Date filter

    1=1

    {% endif %}
    ;;

    view_label: "_Date Tools"
    hidden: yes

  }




}
