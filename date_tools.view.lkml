view: date_tools {

  ## this is a series of fields that must be extended on to a view to add date filter functionality

  extension: required

  ## date_field dimension references a parameter in the base explore that defines the date field for the data

  dimension: date_field {
    sql: ${date_tools_date_field} ;;
    hidden: yes
  }

  dimension_group: date_field_dim_group {
    hidden: yes
    type: time
    sql: ${date_field} ;;
    timeframes: [
      date
      ,month
      ,month_name
      ,week_of_year
      ,week
      ,year
    ]
  }

  parameter: enable_date_tools {
    view_label: "_Date Tools"
    type: unquoted
    allowed_value: {
      value: "yes"
      label: "Yes"
    }
    allowed_value: {
      value: "no"
      label: "No"
    }
    default_value: "no"
  }

  parameter: enable_yoy {
    view_label: "_Date Tools"
    label: "Enable Year over Year?"
    type: unquoted
    allowed_value: {
      value: "yes"
      label: "Yes"
    }
    allowed_value: {
      value: "no"
      label: "No"
    }
    default_value: "no"
  }

  ## timeframes the user can select

  parameter: select_timeframe {
    view_label: "_Date Tools"
    type: unquoted
    default_value: "month"
    allowed_value: {
      value: "year"
      label: "Years"
    }
    allowed_value: {
      value: "month"
      label: "Months"
    }
    allowed_value: {
      value: "week"
      label: "Weeks"
    }
    allowed_value: {
      value: "day"
      label: "Days"
    }
  }

  #  allows a user to select a reference date if they want to do a period over period analysis starting on a past date, rather than the current date

  parameter: select_reference_date {
    type: date_time
    convert_tz: no
    view_label: "_Date Tools"
  }

  #  allows a user to select how many previous periods they'd like to view. default is 1.

  parameter: trailing_n_periods {
    label: "Trailing Periods"
    type: number
    default_value: "1"
    view_label: "_Date Tools"
  }

  # allows a user to select what type of period they'd like - calendar or relative.

  # Relative means the periods will begin at the selected date, and go back in time from there. Ex - if the user selects period type 'weeks' and a 'reference date':
  # - Reference week will be between reference date and reference date - 7
  # - 1 week ago will be between reference date -8 and reference date -14
  # - 2 weeks ago will be between reference date -15 and reference date -21
  # and so on.

  # Calendar uses the date_trunc() function to truncate to the month/week/year the user selects a date within.
  # Ex: User selects reference date of 2022/02/15 (yyyymmdd)
  # -Reference MONTH will be the entire month of February
  # -1 month ago will be January 2022
  # -3 Months ago will be December 2021

  parameter: period_type {
    type: unquoted
    view_label: "_Date Tools"
    allowed_value: {
      label: "Relative (vs. Reference Date)"
      value: "relative"
    }
    allowed_value: {
      label: "Calendar (Aligned to Calendar Weeks/Months/Years)"
      value: "calendar"
    }
  }

  # a helper dimension for the current timestamp. this his hidden, as the user does not need to see it.

  dimension_group: current_timestamp {
    hidden: yes
    type: time
    timeframes: [raw,date,hour_of_day,day_of_week_index,day_of_month,day_of_year]
    convert_tz: yes
    sql: date_trunc('day',date_add('day',-1,GETDATE())) ;;
  }

  dimension: date_period {
    type: number
    hidden: yes
    view_label: "_Date Tools"
    description: "Use this dimension along with \"Select Timeframe\" Filter"
    sql: {% if period_type._parameter_value == 'relative' %} ${relative_date_period} {% else %} ${calendar_date_period} {% endif %};;
  }

  dimension: date_label {
    view_label: "_Date Tools"
    description: "An additional date field that provides an absolute date definition for calendar based on the period selected - for example, month of year, week of year, date, etc."
    sql:
    {% if period_type._parameter_value == 'calendar' %}

      {% if select_timeframe._parameter_value == 'day' %}

      ${date_field_dim_group_date}

      {% elsif select_timeframe._parameter_value == 'week' %}

      'Week of '||${date_field_dim_group_week}

      {% elsif select_timeframe._parameter_value == 'month' %}

      ${date_field_dim_group_month}

      {% elsif select_timeframe._parameter_value == 'year' %}

      ${date_field_dim_group_year}

      {% else %}

      null

      {% endif %}

    {% elsif period_type._parameter_value == 'relative' %}

      '{% parameter select_timeframe %} '||${relative_date_period}

    {% else %}

    null

    {% endif %}

    ;;
  }

  dimension: date_period_formatted {
    view_label: "_Date Tools"
    label: "Relative Date Period"
    order_by_field: date_period
    sql:
      case
        when ${date_period} = 0
          then '{% if select_reference_date._is_filtered %}Reference {% else %}Current {% endif %} {% parameter select_timeframe %}'
        when ${date_period} = 1
          then '1'||'{% parameter select_timeframe %}'||' ago'
        else ${date_period}||' {% parameter select_timeframe %}s'||' ago'
      end;;
  }

  dimension: relative_year {
    view_label: "_Date Tools"
    sql:
      case when ${is_last_year} = true then 'Last Year' else 'This Year' end ;;
  }


  ###############################
  ## begin relative dimensions ##
  ###############################

  # This section contains dimensions to calculate relative time periods - see the definition of relative vs. calendar time periods above.

  # Sets arbitrary date ranges for the selections on the select_timeframe parameter based on desired business logic. this is hidden - the user doesn't need to see this.

  dimension: relative_date_range {
    hidden: yes
    sql:  {% if select_timeframe._parameter_value == 'day' %}
            1
          {% elsif select_timeframe._parameter_value == 'week' %}
            7
          {% elsif select_timeframe._parameter_value == 'month' %}
            30
          {% elsif select_timeframe._parameter_value == 'year' %}
            365
          {% endif %};;

  }

  # relative date (eg how many days ago) when 'relative' option is selected.

  dimension: yoy_date {
    sql: case when ${is_last_year} = true then date_add('year',1,${date_field}) else ${date_field} end ;;
    hidden: yes
  }

  dimension: relative_date {
  sql: datediff('day', {% if enable_yoy._parameter_value == 'yes' %} ${yoy_date} {% else %} ${date_field} {% endif %},{% if select_reference_date._is_filtered %}{% parameter select_reference_date %} {% else %} ${current_timestamp_raw}{% endif %}) - 0
    ;;
    hidden: yes
  }


  # Date period (eg how many periods ago) when 'relative' option is selected

  dimension: relative_date_period {
    hidden: yes
    sql: floor((${relative_date})

                /

               ${relative_date_range})  ;;
  }

  ###############################
  ## begin calendar dimensions ##
  ###############################

  # Date period (eg how many periods ago) when 'calendar' option is selected

  dimension: calendar_date_period {
    hidden: yes
    sql: datediff('{% parameter select_timeframe %}',DATE_TRUNC('{% parameter select_timeframe %}', {% if enable_yoy._parameter_value == 'yes' %} ${yoy_date} {% else %} ${date_field} {% endif %}),DATE_TRUNC('{% parameter select_timeframe %}', {% if select_reference_date._is_filtered %}{% parameter select_reference_date %} {% else %} ${current_timestamp_raw}{% endif %})) ;;
  }

  ###############################
  ## begin yoy dimensions.     ##
  ###############################



  ##################################
  ## begin filter-only dimensions ##
  ##################################

  # This filter is simply used as a sql_always_where filter on the explore, to ensure that only periods within the analysis are shown.

  dimension: date_filter {
    hidden: yes
    sql:  {% if enable_date_tools._parameter_value == 'yes' %}

          ( ${date_field} >= ${min_date} and ${date_field} < ${max_date} )

            {% if enable_yoy._parameter_value == 'yes' %}

            OR

            ( ${yoy_date_filter} )

            {% else %}

            {% endif %}

          {% else %} 1=1 {% endif %}
      ;;
  }

  dimension: yoy_date_filter {
    hidden: yes
    sql: ${date_field} >= ${min_date_ly} and ${date_field} < ${max_date_ly} ;;
  }

  dimension: is_last_year {
    sql: case when ${yoy_date_filter} then true else false end ;;
    hidden: yes
  }

  dimension: max_date {
    hidden: yes
    sql: {% if period_type._parameter_value == 'relative' %} ${rel_max_date} {% else %} ${cal_max_date} {% endif %} ;;
  }

  dimension: max_date_ly {
    sql: date_add('year',-1,${max_date}) ;;
    hidden: yes
  }

  dimension: min_date {
    hidden: yes
    sql: {% if period_type._parameter_value == 'relative' %} ${rel_min_date} {% else %} ${cal_min_date} {% endif %} ;;
  }

  dimension: min_date_ly {
    sql: date_add('year',-1,${min_date}) ;;
    hidden: yes
  }

  dimension: cal_max_date {
    sql: date_trunc('{% parameter select_timeframe %}',date_add('{% parameter select_timeframe %}',1,{% if select_reference_date._is_filtered %}{% parameter select_reference_date %} {% else %} ${current_timestamp_raw}{% endif %})) ;;
    hidden: yes
  }

  dimension: cal_min_date {
    sql: date_trunc('{% parameter select_timeframe %}',date_add('{% parameter select_timeframe %}',({% parameter trailing_n_periods %} * -1),{% if select_reference_date._is_filtered %}{% parameter select_reference_date %} {% else %} ${current_timestamp_raw}{% endif %})) ;;
    hidden: yes
  }

  dimension: rel_max_date {
    sql: date_add('day',1,{% if select_reference_date._is_filtered %}{% parameter select_reference_date %} {% else %} ${current_timestamp_raw}{% endif %}) ;;
    hidden: yes
  }

  dimension: rel_min_date {
    sql: date_add('day',1,date_add('day',( ${relative_date_range} * ( {% parameter trailing_n_periods %} + 1 ) * -1 ), {% if select_reference_date._is_filtered %}{% parameter select_reference_date %} {% else %} ${current_timestamp_raw}{% endif %}));;
    hidden: yes
  }

}
