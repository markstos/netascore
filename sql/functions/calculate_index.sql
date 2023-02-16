DROP TYPE IF EXISTS indicators_rating CASCADE;
CREATE TYPE indicators_rating AS (
    indicator varchar,
    weight numeric
);

CREATE OR REPLACE FUNCTION calculate_index(
    IN bicycle_infrastructure varchar, IN bicycle_infrastructure_weight numeric,
    IN pedestrian_infrastructure varchar, IN pedestrian_infrastructure_weight numeric,
    IN designated_route varchar, IN designated_route_weight numeric,
    IN road_category_bicycle varchar, IN road_category_bicycle_weight numeric,
    IN road_category_pedestrian varchar, IN road_category_pedestrian_weight numeric,
    IN max_speed_bicycle numeric, IN max_speed_bicycle_weight numeric,
    IN max_speed_pedestrian numeric, IN max_speed_pedestrian_weight numeric,
    IN parking varchar, IN parking_weight numeric,
    IN pavement varchar, IN pavement_weight numeric,
    IN width numeric, IN width_weight numeric,
    IN gradient_bicycle numeric, IN gradient_bicycle_weight numeric,
    IN gradient_pedestrian numeric, IN gradient_pedestrian_weight numeric,
    IN number_lanes numeric, IN number_lanes_weight numeric,
    IN facilities numeric, IN facilities_weight numeric,
    IN crossings numeric, IN crossings_weight numeric,
    IN buildings numeric, IN buildings_weight numeric,
    IN greenness numeric, IN greenness_weight numeric,
    IN water boolean, IN water_weight numeric,
    IN noise numeric, IN noise_weight numeric,
    OUT index numeric,
    OUT index_rating numeric,
    OUT indicators_rating indicators_rating[]
)
RETURNS SETOF record AS $$
	DECLARE
	    weights_total numeric;
		weights_sum numeric;
	    indicator numeric;
	    weight numeric;
		index numeric;
	    count integer;
	    index_rating numeric;
	    indicators_rating indicators_rating[];
	BEGIN
		-- TODO: Gewichte anpassen: pavement/gradient
	    IF pavement IN ('gravel', 'soft', 'cobble') AND pavement_weight IS NOT NULL AND
	       gradient_bicycle IN (-4,-3, 3, 4) AND gradient_bicycle_weight IS NOT NULL THEN
			pavement_weight := pavement_weight * 16;
			gradient_bicycle_weight := gradient_bicycle_weight * 16;
		END IF;

		-- TODO: Index anpassen: pedestrian_infrastructure/road_category
		IF pedestrian_infrastructure IN ('sidewalk') AND pedestrian_infrastructure_weight IS NOT NULL AND
		   road_category_pedestrian IN ('secondary', 'primary') AND road_category_pedestrian_weight IS NOT NULL THEN
		    RETURN QUERY
		        SELECT 0.8::numeric AS index,
		               NULL::numeric AS index_rating,
		               NULL::indicators_rating[] AS indicator_rating;
        END IF;

		weights_total := 0;
		weights_total :=
			CASE WHEN bicycle_infrastructure_weight IS NOT NULL THEN bicycle_infrastructure_weight ELSE 0 END +
            CASE WHEN pedestrian_infrastructure_weight IS NOT NULL THEN pedestrian_infrastructure_weight ELSE 0 END +
            CASE WHEN designated_route_weight IS NOT NULL THEN designated_route_weight ELSE 0 END +
            CASE WHEN road_category_bicycle_weight IS NOT NULL THEN road_category_bicycle_weight ELSE 0 END +
            CASE WHEN road_category_pedestrian_weight IS NOT NULL THEN road_category_pedestrian_weight ELSE 0 END +
            CASE WHEN max_speed_bicycle_weight IS NOT NULL THEN max_speed_bicycle_weight ELSE 0 END +
            CASE WHEN max_speed_pedestrian_weight IS NOT NULL THEN max_speed_pedestrian_weight ELSE 0 END +
            CASE WHEN parking_weight IS NOT NULL THEN parking_weight ELSE 0 END +
            CASE WHEN pavement_weight IS NOT NULL THEN pavement_weight ELSE 0 END +
            CASE WHEN width_weight IS NOT NULL THEN width_weight ELSE 0 END +
            CASE WHEN gradient_bicycle_weight IS NOT NULL THEN gradient_bicycle_weight ELSE 0 END +
            CASE WHEN gradient_pedestrian_weight IS NOT NULL THEN gradient_pedestrian_weight ELSE 0 END +
            CASE WHEN number_lanes_weight IS NOT NULL THEN number_lanes_weight ELSE 0 END +
            CASE WHEN facilities_weight IS NOT NULL THEN facilities_weight ELSE 0 END +
            CASE WHEN crossings_weight IS NOT NULL THEN crossings_weight ELSE 0 END +
            CASE WHEN buildings_weight IS NOT NULL THEN buildings_weight ELSE 0 END +
            CASE WHEN greenness_weight IS NOT NULL THEN greenness_weight ELSE 0 END +
            CASE WHEN water_weight IS NOT NULL THEN water_weight ELSE 0 END +
            CASE WHEN noise_weight IS NOT NULL THEN noise_weight ELSE 0 END;

		weights_sum := 0;
		weights_sum :=
			CASE WHEN bicycle_infrastructure IS NOT NULL AND bicycle_infrastructure_weight IS NOT NULL THEN bicycle_infrastructure_weight ELSE 0 END +
            CASE WHEN pedestrian_infrastructure IS NOT NULL AND pedestrian_infrastructure_weight IS NOT NULL THEN pedestrian_infrastructure_weight ELSE 0 END +
            CASE WHEN designated_route IS NOT NULL AND designated_route_weight IS NOT NULL THEN designated_route_weight ELSE 0 END +
            CASE WHEN road_category_bicycle IS NOT NULL AND road_category_bicycle_weight IS NOT NULL THEN road_category_bicycle_weight ELSE 0 END +
            CASE WHEN road_category_pedestrian IS NOT NULL AND road_category_pedestrian_weight IS NOT NULL THEN road_category_pedestrian_weight ELSE 0 END +
            CASE WHEN max_speed_bicycle IS NOT NULL AND max_speed_bicycle_weight IS NOT NULL THEN max_speed_bicycle_weight ELSE 0 END +
            CASE WHEN max_speed_pedestrian IS NOT NULL AND max_speed_pedestrian_weight IS NOT NULL THEN max_speed_pedestrian_weight ELSE 0 END +
            CASE WHEN parking IS NOT NULL AND parking_weight IS NOT NULL THEN parking_weight ELSE 0 END +
            CASE WHEN pavement IS NOT NULL AND pavement_weight IS NOT NULL THEN pavement_weight ELSE 0 END +
            CASE WHEN width IS NOT NULL AND width_weight IS NOT NULL THEN width_weight ELSE 0 END +
            CASE WHEN gradient_bicycle IS NOT NULL AND gradient_bicycle_weight IS NOT NULL THEN gradient_bicycle_weight ELSE 0 END +
            CASE WHEN gradient_pedestrian IS NOT NULL AND gradient_pedestrian_weight IS NOT NULL THEN gradient_pedestrian_weight ELSE 0 END +
            CASE WHEN number_lanes IS NOT NULL AND number_lanes_weight IS NOT NULL THEN number_lanes_weight ELSE 0 END +
            CASE WHEN facilities IS NOT NULL AND facilities_weight IS NOT NULL THEN facilities_weight ELSE 0 END +
            CASE WHEN crossings IS NOT NULL AND crossings_weight IS NOT NULL THEN crossings_weight ELSE 0 END +
            CASE WHEN buildings IS NOT NULL AND buildings_weight IS NOT NULL THEN buildings_weight ELSE 0 END +
            CASE WHEN greenness IS NOT NULL AND greenness_weight IS NOT NULL THEN greenness_weight ELSE 0 END +
            CASE WHEN water IS NOT NULL AND water_weight IS NOT NULL THEN water_weight ELSE 0 END +
            CASE WHEN noise IS NOT NULL AND noise_weight IS NOT NULL THEN noise_weight ELSE 0 END;

		IF weights_sum > 0 THEN
		    index := 0;
		    count := 0;

            IF bicycle_infrastructure IS NOT NULL AND bicycle_infrastructure_weight IS NOT NULL THEN
                indicator :=
                    CASE
						WHEN bicycle_infrastructure = 'bicycle_way' THEN 0
						WHEN bicycle_infrastructure = 'mixed_way' THEN 0.1
						WHEN bicycle_infrastructure = 'bicycle_lane' THEN 0.25
						WHEN bicycle_infrastructure = 'bus_lane' THEN 0.25
						WHEN bicycle_infrastructure = 'shared_lane' THEN 0.5
						WHEN bicycle_infrastructure = 'undefined' THEN 0.8
						WHEN bicycle_infrastructure = 'no' THEN 1
					END;
                weight := bicycle_infrastructure_weight / weights_sum;
                index := index + indicator * weight;
                count := count + 1;
                indicators_rating := array_append(indicators_rating, ('bicycle_infrastructure', indicator * weight)::indicators_rating);
            END IF;

            IF pedestrian_infrastructure IS NOT NULL AND pedestrian_infrastructure_weight IS NOT NULL THEN
				indicator :=
					CASE
						WHEN pedestrian_infrastructure = 'pedestrian_area' THEN 0
						WHEN pedestrian_infrastructure = 'pedestrian_way' THEN 0
						WHEN pedestrian_infrastructure = 'mixed_way' THEN 0.15
						WHEN pedestrian_infrastructure = 'stairs' THEN 0.3
						WHEN pedestrian_infrastructure = 'sidewalk' THEN 0.5
						WHEN pedestrian_infrastructure = 'no' 	THEN 1
					END;
                weight := pedestrian_infrastructure_weight / weights_sum;
                index := index + indicator * weight;
                count := count + 1;
                indicators_rating := array_append(indicators_rating, ('pedestrian_infrastructure', indicator * weight)::indicators_rating);
            END IF;

			IF designated_route IS NOT NULL AND designated_route_weight IS NOT NULL THEN
				indicator :=
				    CASE
						WHEN designated_route = 'international' THEN 0
						WHEN designated_route = 'national' THEN 0.1
						WHEN designated_route = 'regional' THEN 0.15
						WHEN designated_route = 'local' THEN 0.2
						WHEN designated_route = 'unknown' THEN 0.2
						WHEN designated_route = 'no' THEN 1
					END;
                weight := designated_route_weight / weights_sum;
                index := index + indicator * weight;
                count := count + 1;
                indicators_rating := array_append(indicators_rating, ('designated_route', indicator * weight)::indicators_rating);
            END IF;

			IF road_category_bicycle IS NOT NULL AND road_category_bicycle_weight IS NOT NULL THEN
				indicator :=
				    CASE
						WHEN road_category_bicycle = 'primary' THEN 1
						WHEN road_category_bicycle = 'secondary' THEN 0.8
						WHEN road_category_bicycle = 'residential' THEN 0.2
						WHEN road_category_bicycle = 'service' THEN 0.15
						WHEN road_category_bicycle = 'calmed' THEN 0.1
						WHEN road_category_bicycle = 'no_mit' THEN 0
						WHEN road_category_bicycle = 'path' THEN 1
					END;
                weight := road_category_bicycle_weight / weights_sum;
                index := index + indicator * weight;
                count := count + 1;
                indicators_rating := array_append(indicators_rating, ('road_category_bicycle', indicator * weight)::indicators_rating);
            END IF;

			IF road_category_pedestrian IS NOT NULL AND road_category_pedestrian_weight IS NOT NULL THEN
				indicator :=
                    CASE
						WHEN road_category_pedestrian = 'primary' THEN 1
						WHEN road_category_pedestrian = 'secondary' THEN 0.8
						WHEN road_category_pedestrian = 'residential' THEN 0.2
						WHEN road_category_pedestrian = 'service' THEN 0.15
						WHEN road_category_pedestrian = 'calmed' THEN 0.1
						WHEN road_category_pedestrian = 'no_mit' THEN 0
						WHEN road_category_pedestrian = 'path' THEN 0
					END;
                weight := road_category_pedestrian_weight / weights_sum;
                index := index + indicator * weight;
                count := count + 1;
                indicators_rating := array_append(indicators_rating, ('road_category_pedestrian', indicator * weight)::indicators_rating);
            END IF;

			IF max_speed_bicycle IS NOT NULL AND max_speed_bicycle_weight IS NOT NULL THEN
				indicator :=
				    CASE
						WHEN max_speed_bicycle >= 100 THEN 1
						WHEN max_speed_bicycle >= 80 THEN 0.8
						WHEN max_speed_bicycle >= 70 THEN 0.7
						WHEN max_speed_bicycle >= 60 THEN 0.6
						WHEN max_speed_bicycle >= 50 THEN 0.4
						WHEN max_speed_bicycle >= 30 THEN 0.15
						WHEN max_speed_bicycle > 0 THEN 0.1
						WHEN max_speed_bicycle = 0 THEN 0
					END;
                weight := max_speed_bicycle_weight / weights_sum;
                index := index + indicator * weight;
                count := count + 1;
                indicators_rating := array_append(indicators_rating, ('max_speed_bicycle', indicator * weight)::indicators_rating);
            END IF;

			IF max_speed_pedestrian IS NOT NULL AND max_speed_pedestrian_weight IS NOT NULL THEN
				indicator :=
				    CASE
						WHEN max_speed_pedestrian >= 100 THEN 1
						WHEN max_speed_pedestrian >= 80 THEN 0.8
						WHEN max_speed_pedestrian >= 70 THEN 0.7
						WHEN max_speed_pedestrian >= 60 THEN 0.6
						WHEN max_speed_pedestrian >= 50 THEN 0.4
						WHEN max_speed_pedestrian >= 30 THEN 0.15
						WHEN max_speed_pedestrian > 0 THEN 0.1
						WHEN max_speed_pedestrian = 0 THEN 0
					END;
                weight := max_speed_pedestrian_weight / weights_sum;
                index := index + indicator * weight;
                count := count + 1;
                indicators_rating := array_append(indicators_rating, ('max_speed_pedestrian', indicator * weight)::indicators_rating);
            END IF;

			IF parking IS NOT NULL AND parking_weight IS NOT NULL THEN
				indicator :=
				    CASE
						WHEN parking = 'yes' THEN 1
						WHEN parking = 'no' THEN 0
					END;
                weight := parking_weight / weights_sum;
                index := index + indicator * weight;
                count := count + 1;
                indicators_rating := array_append(indicators_rating, ('parking', indicator * weight)::indicators_rating);
            END IF;

			IF pavement IS NOT NULL AND pavement_weight IS NOT NULL THEN
				indicator :=
				    CASE
						WHEN pavement = 'asphalt' THEN 0
						WHEN pavement = 'gravel' THEN 0.25
						WHEN pavement = 'soft' THEN 0.6
						WHEN pavement = 'cobble' THEN 1
					END;
                weight := pavement_weight / weights_sum;
                index := index + indicator * weight;
                count := count + 1;
                indicators_rating := array_append(indicators_rating, ('pavement', indicator * weight)::indicators_rating);
			END IF;

			IF width IS NOT NULL AND width_weight IS NOT NULL THEN
				indicator :=
				    CASE
						WHEN width > 5 THEN 0
						WHEN width > 4 THEN 0.1
						WHEN width > 3 THEN 0.15
						WHEN width > 2 THEN 0.5
						WHEN width >= 0 THEN 1
					END;
                weight := width_weight / weights_sum;
                index := index + indicator * weight;
                count := count + 1;
                indicators_rating := array_append(indicators_rating, ('width', indicator * weight)::indicators_rating);
            END IF;

			IF gradient_bicycle IS NOT NULL AND gradient_bicycle_weight IS NOT NULL THEN
				indicator :=
				    CASE
						WHEN gradient_bicycle = 4 THEN 1
						WHEN gradient_bicycle = 3 THEN 0.75
						WHEN gradient_bicycle = 2 THEN 0.6
						WHEN gradient_bicycle = 1 THEN 0.5
						WHEN gradient_bicycle = 0 THEN 0.1
						WHEN gradient_bicycle = -1 THEN 0
						WHEN gradient_bicycle = -2 THEN 0.05
						WHEN gradient_bicycle = -3 THEN 0.65
						WHEN gradient_bicycle = -4 THEN 1
					END;
                weight := gradient_bicycle_weight / weights_sum;
                index := index + indicator * weight;
                count := count + 1;
                indicators_rating := array_append(indicators_rating, ('gradient_bicycle', indicator * weight)::indicators_rating);
            END IF;

			IF gradient_pedestrian IS NOT NULL AND gradient_pedestrian_weight IS NOT NULL THEN
				indicator :=
				    CASE
						WHEN gradient_pedestrian = 4 THEN 0.75
						WHEN gradient_pedestrian = 3 THEN 0.5
						WHEN gradient_pedestrian = 2 THEN 0.3
						WHEN gradient_pedestrian = 1 THEN 0
						WHEN gradient_pedestrian = 0 THEN 0
						WHEN gradient_pedestrian = -1 THEN 0
						WHEN gradient_pedestrian = -2 THEN 0.3
						WHEN gradient_pedestrian = -3 THEN 0.5
						WHEN gradient_pedestrian = -4 THEN 0.75
					END;
                weight := gradient_pedestrian_weight / weights_sum;
                index := index + indicator * weight;
                count := count + 1;
                indicators_rating := array_append(indicators_rating, ('gradient_pedestrian', indicator * weight)::indicators_rating);
            END IF;

			IF number_lanes IS NOT NULL AND number_lanes_weight IS NOT NULL THEN
				indicator :=
				    CASE
						WHEN number_lanes > 4 THEN 1
						WHEN number_lanes > 3 THEN 0.9
						WHEN number_lanes > 2 THEN 0.8
						WHEN number_lanes > 1 THEN 0.5
						WHEN number_lanes >= 0 THEN 0
					END;
                weight := number_lanes_weight / weights_sum;
                index := index + indicator * weight;
                count := count + 1;
                indicators_rating := array_append(indicators_rating, ('number_lanes', indicator * weight)::indicators_rating);
            END IF;

			IF facilities IS NOT NULL AND facilities_weight IS NOT NULL THEN
				indicator :=
				    CASE
						WHEN facilities > 0 THEN 0
						WHEN facilities = 0 THEN 1
					END;
                weight := facilities_weight / weights_sum;
                index := index + indicator * weight;
                count := count + 1;
                indicators_rating := array_append(indicators_rating, ('facilities', indicator * weight)::indicators_rating);
            END IF;

			IF crossings IS NOT NULL AND crossings_weight IS NOT NULL THEN
				indicator :=
				    CASE
						WHEN crossings = 0 AND road_category_pedestrian IN ('primary', 'secondary') OR road_category_pedestrian IS NULL THEN 1
						WHEN crossings = 0 AND road_category_pedestrian IN ('residential') THEN 0.5
						ELSE 0
					END;
                weight := crossings_weight / weights_sum;
                index := index + indicator * weight;
                count := count + 1;
                indicators_rating := array_append(indicators_rating, ('crossings', indicator * weight)::indicators_rating);
            END IF;

			IF buildings IS NOT NULL AND buildings_weight IS NOT NULL THEN
				indicator :=
				    CASE
						WHEN buildings >= 80 THEN 1
						WHEN buildings > 60 THEN 0.8
						WHEN buildings > 40 THEN 0.6
						WHEN buildings > 20 THEN 0.4
						WHEN buildings > 0 THEN 0.2
						WHEN buildings = 0 THEN 0
					END;
                weight := buildings_weight / weights_sum;
                index := index + indicator * weight;
                count := count + 1;
                indicators_rating := array_append(indicators_rating, ('buildings', indicator * weight)::indicators_rating);
            END IF;

			IF greenness IS NOT NULL AND greenness_weight IS NOT NULL THEN
				indicator :=
				    CASE
						WHEN greenness > 75 THEN 0
						WHEN greenness > 50 THEN 0.1
						WHEN greenness > 25 THEN 0.2
						WHEN greenness > 0 THEN 0.3
						WHEN greenness = 0 THEN 1
					END;
                weight := greenness_weight / weights_sum;
                index := index + indicator * weight;
                count := count + 1;
                indicators_rating := array_append(indicators_rating, ('greenness', indicator * weight)::indicators_rating);
            END IF;

			IF water IS NOT NULL AND water_weight IS NOT NULL THEN
				indicator :=
				    CASE
						WHEN water THEN 0
						ELSE 1
					END;
                weight := water_weight / weights_sum;
                index := index + indicator * weight;
                count := count + 1;
                indicators_rating := array_append(indicators_rating, ('water', indicator * weight)::indicators_rating);
            END IF;

			IF noise IS NOT NULL AND noise_weight IS NOT NULL THEN
				indicator :=
				    CASE
						WHEN noise > 70 THEN 1
						WHEN noise > 55 THEN 0.4
						WHEN noise > 10 THEN 0.2
						WHEN noise >= 0 THEN 0
					END;
                weight := noise_weight / weights_sum;
                index := index + indicator * weight;
                count := count + 1;
                indicators_rating := array_append(indicators_rating, ('noise', indicator * weight)::indicators_rating);
            END IF;

        END IF;

		index_rating = weights_sum / weights_total;

		indicators_rating := (
            WITH a AS (
                SELECT unnest(indicators_rating)
                ORDER BY (unnest(indicators_rating)).weight DESC
                -- LIMIT 1
            )
            SELECT array_agg(unnest)
            FROM a
        );

		RETURN QUERY
		    SELECT round(index, 4) AS index,
		           round(weights_sum / weights_total, 4) AS index_rating,
		           indicators_rating;
	END
$$ LANGUAGE plpgsql;