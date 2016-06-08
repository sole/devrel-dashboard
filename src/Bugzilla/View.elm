module Bugzilla.View exposing (..)

import Bugzilla.Models exposing (Model, Bug, Priority(..), Resolution(..), SortDir(..), SortField(..), State(..), Network(..))
import Bugzilla.Messages exposing (Msg(..))
import Bugzilla.ViewHelpers exposing (stateDescription, stateOrder, priorityOrder, bugTaxon)
import Dict
import Html exposing (..)
import Html.Attributes exposing (id, class, attribute, target, href, title, classList, type', checked, value, placeholder)
import Html.Events exposing (onClick, onCheck, onInput)
import Set
import String


-- VIEW


view : Model -> Html Msg
view model =
    let
        visibleBugs : List Bug
        visibleBugs =
            model.bugs
                |> Dict.values
                |> List.filter (matchesShowOpen model)
                |> List.filter (matchesPriority model)
                |> List.filter (matchesFilterText model)
                |> sortBugs model.sort
    in
        div [ class "bugs" ]
            [ sortContainer model
            , case model.networkStatus of
                Fetching ->
                    div [ class "loading" ] [ text "Fetching data from Bugzilla..." ]

                Failed ->
                    div [ class "loading-error" ] [ text "Error fetching data. Please refresh." ]

                Loaded ->
                    if List.isEmpty visibleBugs then
                        div [ class "no-bugs" ] [ text "No bugs match your filter settings." ]
                    else
                        ul [] (List.map (\bug -> li [] [ renderBug bug ]) visibleBugs)
            ]



-- HELPERS : Predicates


matchesFilterText : Model -> Bug -> Bool
matchesFilterText model bug =
    List.any (String.contains <| String.toLower model.filterText)
        [ String.toLower (bugTaxon bug)
        , String.toLower bug.summary
        ]


matchesPriority : Model -> Bug -> Bool
matchesPriority { visiblePriorities } { priority } =
    List.isEmpty visiblePriorities || List.member priority visiblePriorities


matchesShowOpen : Model -> Bug -> Bool
matchesShowOpen { showClosed } { open } =
    open || showClosed



-- HELPERS : Transformations


sortBugs : ( SortField, SortDir ) -> List Bug -> List Bug
sortBugs ( field, direction ) bugs =
    let
        sort =
            case field of
                Id ->
                    List.sortBy .id

                ProductComponent ->
                    List.sortBy (\x -> ( x.product, x.component, x.summary ))

                Priority ->
                    List.sortBy (\x -> ( priorityOrder x.priority, x.product, x.component, x.summary ))

        transform =
            if direction == Asc then
                identity
            else
                List.reverse
    in
        bugs
            |> sort
            |> transform



-- WIDGETS : Bugs


renderBug : Bug -> Html Msg
renderBug bug =
    let
        bugUrl =
            "https://bugzilla.mozilla.org/show_bug.cgi?id=" ++ (toString bug.id)

        prioString =
            Maybe.withDefault "Untriaged" (Maybe.map toString bug.priority)
    in
        div
            [ class "bug"
            , attribute "data-open" (toString bug.open)
            , attribute "data-status" (stateDescription bug.state)
            , attribute "data-priority" prioString
            ]
            [ div [ class "bug-header" ]
                [ div [ class "oneline", title (bugTaxon bug) ]
                    [ text (bugTaxon bug) ]
                ]
            , div [ class "bug-body" ]
                [ a [ target "_blank", href bugUrl, class "bug-summary" ]
                    [ text bug.summary ]
                , a [ target "_blank", href bugUrl, class "bug-id" ]
                    [ text <| "#" ++ (toString bug.id) ]
                ]
            ]



-- WIDGETS : Sorting and Filtering


sortContainer : Model -> Html Msg
sortContainer model =
    div [ id "sort-bar" ]
        [ input
            [ class "filter-text"
            , attribute "list" "datalist-products"
            , placeholder "Filter Bugs by Product, Component, or Summary Text"
            , onInput FilterText
            ]
            []
        , datalist [ id "datalist-products" ]
            (model.bugs
                |> Dict.values
                |> List.map (\bug -> [ bug.product, bugTaxon bug ])
                |> List.concat
                |> Set.fromList
                |> Set.toList
                |> List.map (\product -> option [ value product ] [])
            )
        , div [ class "filter-priorities" ]
            ([ ( Just P1, "P1", "Critical" )
             , ( Just P2, "P2", "Major" )
             , ( Just P3, "P3", "Minor" )
             , ( Just PX, "PX", "Ignore" )
             , ( Nothing, "Untriaged", "" )
             ]
                |> List.map (priorityFilterWidget model)
                |> List.intersperse (text ", ")
                |> (::) (text "Priorities: ")
            )
        , closedFilterWidget model
        , div []
            ([ ( Id, "Number" )
             , ( ProductComponent, "Product / Component" )
             , ( Priority, "Priority" )
             ]
                |> List.map (sortWidget model)
                |> List.intersperse (text ", ")
                |> (::) (text "Sort: ")
            )
        ]


sortWidget : Model -> ( SortField, String ) -> Html Msg
sortWidget model ( field, label ) =
    button
        [ onClick <| SortBy field
        , classList
            [ ( "as-text", True )
            , ( "active", field == fst model.sort )
            , ( "sort-asc", model.sort == ( field, Asc ) )
            , ( "sort-desc", model.sort == ( field, Desc ) )
            ]
        ]
        [ text label ]


closedFilterWidget : Model -> Html Msg
closedFilterWidget model =
    label []
        [ input
            [ type' "checkbox"
            , checked <| not model.showClosed
            , onCheck <| always ToggleShowClosed
            ]
            []
        , text "Hide Closed Bugs"
        ]


priorityFilterWidget : Model -> ( Maybe Priority, String, String ) -> Html Msg
priorityFilterWidget model ( priority, description, explanation ) =
    let
        tooltip : String
        tooltip =
            if explanation == "" then
                ""
            else
                description ++ "—" ++ explanation

        filterClass : String
        filterClass =
            priority
                |> Maybe.map toString
                |> Maybe.withDefault "untriaged"
                |> (++) "priority-filter-"
                |> String.toLower
    in
        label
            [ class "priority-widget"
            , title tooltip
            ]
            [ input
                [ type' "checkbox"
                , checked (List.member priority model.visiblePriorities)
                , onCheck <| always (TogglePriority priority)
                ]
                []
            , (if explanation == "" then
                span
               else
                abbr
              )
                [ class filterClass ]
                [ text description ]
            ]
