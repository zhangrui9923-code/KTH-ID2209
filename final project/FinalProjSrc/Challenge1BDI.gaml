model FestivalSimulationBDI

global {
    int num_guests <- 50;
    int num_bars <- 3;
    int num_stages <- 2;
    bool use_fipa <- true;
    float interaction_distance <- 5.0;
    float env_size <- 100.0;
    geometry shape <- square(env_size);
    
    float global_avg_happiness <- 0.5;
    int total_positive_interactions <- 0;
    int total_negative_interactions <- 0;
    int total_fipa_messages_sent <- 0;
    
    // BDI METRICS
    int total_bdi_actions <- 0;
    int total_belief_updates <- 0;
    int total_intention_changes <- 0;
    
    list<string> type_names <- ["Elderly", "Child", "Student", "Office Worker", "Couple"];
    list<rgb> type_colors <- [#gray, #yellow, #blue, #brown, #pink];
    
    init {
        write "============================================";
        write "FESTIVAL SIMULATION WITH BDI ARCHITECTURE";
        write "Belief-Desire-Intention Model";
        write "============================================";
        
        list<point> bar_locations <- [{40.0, 80.0}, {20.0, 50.0}, {60.0, 60.0}];
        loop i from: 0 to: length(bar_locations) - 1 {
            create Bar {
                location <- bar_locations[i];
                bar_name <- "Bar_" + string(i);
                quality <- rnd(0.3, 0.9);
            }
        }
        
        list<point> stage_locations <- [{80.0, 20.0}, {50.0, 10.0}];
        loop j from: 0 to: length(stage_locations) - 1 {
            create Stage {
                location <- stage_locations[j];
                stage_name <- "Stage_" + string(j);
                performance_quality <- rnd(0.4, 1.0);
            }
        }
        
        create Guest number: num_guests {
            location <- {rnd(env_size), rnd(env_size)};
            guest_type <- rnd(1, 5);
            
            if (guest_type = 1) {
                sociability <- rnd(0.3, 0.5);
                risk_aversion <- rnd(0.7, 0.95);
                trust <- rnd(0.6, 0.85);
            } else if (guest_type = 2) {
                sociability <- rnd(0.7, 1.0);
                risk_aversion <- rnd(0.05, 0.3);
                trust <- rnd(0.7, 0.95);
            } else if (guest_type = 3) {
                sociability <- rnd(0.6, 0.9);
                risk_aversion <- rnd(0.2, 0.5);
                trust <- rnd(0.5, 0.8);
            } else if (guest_type = 4) {
                sociability <- rnd(0.4, 0.7);
                risk_aversion <- rnd(0.5, 0.8);
                trust <- rnd(0.3, 0.6);
            } else {
                sociability <- rnd(0.3, 0.6);
                risk_aversion <- rnd(0.4, 0.7);
                trust <- rnd(0.5, 0.8);
            }
        }
        
        write "Initialization complete. " + string(num_guests) + " BDI agents created.";
    }
    
    reflex update_metrics {
        if (length(Guest) > 0) {
            global_avg_happiness <- mean(Guest collect each.happiness);
        }
    }
    
    reflex report when: (cycle mod 100) = 0 and cycle > 0 {
        write "--- Cycle " + string(cycle) + " BDI Report ---";
        write "  Happiness: " + string(global_avg_happiness with_precision 3);
        write "  Positive: " + string(total_positive_interactions);
        write "  Negative: " + string(total_negative_interactions);
        write "  BDI Actions: " + string(total_bdi_actions);
        write "  Beliefs Updated: " + string(total_belief_updates);
        write "  Intentions Changed: " + string(total_intention_changes);
    }
}

species Bar {
    string bar_name;
    float quality;
    int visitors_today <- 0;
    
    aspect default {
        draw square(6) color: #brown border: #black;
        draw bar_name color: #white font: font("Arial", 10, #bold) at: location + {0, -4};
    }
}

species Stage {
    string stage_name;
    float performance_quality;
    int audience_count <- 0;
    
    reflex change_performance when: (cycle mod 200) = 0 {
        performance_quality <- rnd(0.3, 1.0);
    }
    
    aspect default {
        draw triangle(8) color: #purple border: #black;
        draw stage_name color: #white font: font("Arial", 10, #bold) at: location + {0, -5};
    }
}

species Guest skills: [moving, fipa, simple_bdi] {
    
    // ========================================================================
    // BASIC ATTRIBUTES
    // ========================================================================
    int guest_type;
    float sociability;
    float risk_aversion;
    float trust;
    float happiness <- 0.5;
    float energy <- 1.0;
    
    string current_state <- "wandering";
    point target_location;
    Bar current_bar;
    Stage current_stage;
    int time_at_venue <- 0;
    
    map<Guest, int> last_interaction_cycle;
    map<Guest, float> social_memory <- []; // Track impression of other guests
    int fipa_cooldown <- 0;
    
    // ========================================================================
    // BDI ARCHITECTURE COMPONENTS
    // ========================================================================
    
    // BELIEFS: Agent's knowledge about the world
    list<string> my_beliefs <- [];
    
    // DESIRES: Agent's goals
    list<string> my_desires <- [];
    
    // INTENTION: Currently committed goal
    string current_intention <- nil;
    string previous_intention <- nil;
    
    // ========================================================================
    // INITIALIZATION
    // ========================================================================
    init {
        // Initialize type-specific desires
        my_desires <- ["be_happy"];
        
        if (guest_type = 1) { // Elderly
            my_desires <- my_desires + "rest";
            my_desires <- my_desires + "avoid_crowd";
        } else if (guest_type = 2) { // Child
            my_desires <- my_desires + "socialize";
            my_desires <- my_desires + "explore";
        } else if (guest_type = 3) { // Student
            my_desires <- my_desires + "socialize";
            my_desires <- my_desires + "find_fun";
        } else if (guest_type = 4) { // Office Worker
            my_desires <- my_desires + "rest";
            if (sociability > 0.5) {
                my_desires <- my_desires + "socialize";
            }
        } else { // Couple
            my_desires <- my_desires + "find_fun";
        }
        
        // Initialize beliefs based on starting conditions
        if (energy > 0.7) {
            my_beliefs <- my_beliefs + "energetic";
        }
    }
    
    // ========================================================================
    // BDI CYCLE: PERCEPTION → BELIEFS → DESIRES → INTENTIONS → ACTIONS
    // ========================================================================
    
    // STEP 1: PERCEPTION - Sense the environment
    reflex perceive_environment {
        // This happens automatically through sensors
        // We gather info about: energy, nearby guests, venue quality, etc.
    }
    
    // STEP 2: UPDATE BELIEFS - Form beliefs based on perceptions
    reflex update_beliefs {
        total_belief_updates <- total_belief_updates + 1;
        
        // Clear old beliefs (beliefs change based on current perception)
        my_beliefs <- [];
        
        // BELIEF 1: Energy state
        if (energy < 0.3) {
            my_beliefs <- my_beliefs + "tired";
        } else if (energy > 0.7) {
            my_beliefs <- my_beliefs + "energetic";
        }
        
        // BELIEF 2: Crowd state
        list<Guest> nearby <- Guest at_distance 15.0;
        if (length(nearby) > 10) {
            my_beliefs <- my_beliefs + "crowded";
        } else if (length(nearby) < 3) {
            my_beliefs <- my_beliefs + "quiet";
        }
        
        // BELIEF 3: Venue quality (if at a venue)
        if (current_bar != nil) {
            if (current_bar.quality > 0.6) {
                my_beliefs <- my_beliefs + "good_venue";
            } else if (current_bar.quality < 0.4) {
                my_beliefs <- my_beliefs + "bad_venue";
            }
        } else if (current_stage != nil) {
            if (current_stage.performance_quality > 0.7) {
                my_beliefs <- my_beliefs + "good_venue";
            } else if (current_stage.performance_quality < 0.4) {
                my_beliefs <- my_beliefs + "bad_venue";
            }
        }
        
        // BELIEF 4: Happiness state
        if (happiness < 0.3) {
            my_beliefs <- my_beliefs + "unhappy";
        } else if (happiness > 0.7) {
            my_beliefs <- my_beliefs + "happy";
        }
        
        // BELIEF 5: Social environment
        list<Guest> very_close <- (Guest at_distance interaction_distance) where (each != self);
        if (length(very_close) > 0) {
            my_beliefs <- my_beliefs + "others_nearby";
            
            // Check if we know any of them positively
            bool has_friend <- false;
            loop g over: very_close {
                if (social_memory.keys contains g) {
                    if (social_memory[g] > 0.6) {
                        has_friend <- true;
                    }
                }
            }
            if (has_friend) {
                my_beliefs <- my_beliefs + "friend_nearby";
            }
        }
    }
    
    // STEP 3: GENERATE/UPDATE DESIRES - Based on beliefs and personality
    reflex apply_bdi_rules {
        // Rule 1: tired → rest (HIGH PRIORITY)
        if (my_beliefs contains "tired" and not (my_desires contains "rest")) {
            my_desires <- my_desires + "rest";
        }
        
        // Rule 2: Remove rest desire when recovered
        if (not (my_beliefs contains "tired") and energy > 0.6 and my_desires contains "rest") {
            my_desires <- my_desires - "rest";
        }
        
        // Rule 3: energetic + social personality → socialize
        if (my_beliefs contains "energetic" and sociability > 0.5 and not (my_desires contains "socialize")) {
            my_desires <- my_desires + "socialize";
        }
        
        // Rule 4: crowded + risk averse → avoid_crowd
        if (my_beliefs contains "crowded" and risk_aversion > 0.6 and not (my_desires contains "avoid_crowd")) {
            my_desires <- my_desires + "avoid_crowd";
        }
        
        // Rule 5: quiet + social → socialize
        if (my_beliefs contains "quiet" and sociability > 0.6 and not (my_desires contains "socialize")) {
            my_desires <- my_desires + "socialize";
        }
        
        // Rule 6: unhappy → find_fun
        if (my_beliefs contains "unhappy" and not (my_desires contains "find_fun")) {
            my_desires <- my_desires + "find_fun";
        }
        
        // Rule 7: bad_venue → explore (leave and find better)
        if (my_beliefs contains "bad_venue" and not (my_desires contains "explore")) {
            my_desires <- my_desires + "explore";
        }
        
        // Rule 8: friend_nearby + social → socialize
        if (my_beliefs contains "friend_nearby" and sociability > 0.5 and not (my_desires contains "socialize")) {
            my_desires <- my_desires + "socialize";
        }
    }
    
    // STEP 4: INTENTION SELECTION - Choose which desire to pursue
    reflex select_intention {
        string new_intention <- nil;
        
        // Priority-based selection (most urgent first)
        if (my_desires contains "rest") {
            new_intention <- "rest";
        } else if (my_desires contains "avoid_crowd") {
            new_intention <- "avoid_crowd";
        } else if (my_desires contains "socialize") {
            new_intention <- "socialize";
        } else if (my_desires contains "find_fun") {
            new_intention <- "find_fun";
        } else if (my_desires contains "explore") {
            new_intention <- "explore";
        } else if (my_desires contains "be_happy") {
            new_intention <- "be_happy";
        }
        
        // Track intention changes
        if (new_intention != current_intention and new_intention != nil) {
            previous_intention <- current_intention;
            current_intention <- new_intention;
            total_intention_changes <- total_intention_changes + 1;
        }
    }
    
    // STEP 5: EXECUTE ACTIONS - Based on current intention
    reflex execute_intention {
        if (current_intention = "rest") {
            do action_rest;
        } else if (current_intention = "avoid_crowd") {
            do action_avoid_crowd;
        } else if (current_intention = "socialize") {
            do action_socialize;
        } else if (current_intention = "find_fun") {
            do action_find_fun;
        } else if (current_intention = "explore") {
            do action_explore;
        } else if (current_intention = "be_happy") {
            do action_be_happy;
        }
    }
    
    // ========================================================================
    // BDI ACTIONS (PLANS)
    // ========================================================================
    
    action action_rest {
        total_bdi_actions <- total_bdi_actions + 1;
        
        // Recover energy
        energy <- energy + 0.03;
        if (energy > 1.0) { energy <- 1.0; }
        
        // Move to a quiet stage if wandering
        if (current_state = "wandering" and length(Stage) > 0) {
            Stage s <- Stage closest_to self;
            target_location <- s.location;
            current_state <- "going_to_venue";
            current_stage <- s;
        }
    }
    
    action action_avoid_crowd {
        total_bdi_actions <- total_bdi_actions + 1;
        
        list<Guest> nearby <- Guest at_distance 15.0;
        if (length(nearby) > 8) {
            // Calculate direction away from crowd center
            point crowd_center <- mean(nearby collect each.location);
            point away <- location - crowd_center;
            target_location <- location + away;
            
            // Keep within bounds
            if (target_location.x < 5.0) { target_location <- {5.0, target_location.y}; }
            if (target_location.x > env_size - 5.0) { target_location <- {env_size - 5.0, target_location.y}; }
            if (target_location.y < 5.0) { target_location <- {target_location.x, 5.0}; }
            if (target_location.y > env_size - 5.0) { target_location <- {target_location.x, env_size - 5.0}; }
            
            do goto target: target_location speed: 1.5;
            
            // Leave venue if currently there
            if (current_bar != nil or current_stage != nil) {
                current_state <- "wandering";
                current_bar <- nil;
                current_stage <- nil;
            }
        }
    }
    
    action action_socialize {
        total_bdi_actions <- total_bdi_actions + 1;
        
        list<Guest> nearby <- (Guest at_distance interaction_distance) where (each != self);
        
        if (length(nearby) > 0) {
            // Interact with nearby guests
            loop other over: nearby {
                bool can_interact <- true;
                if (last_interaction_cycle contains_key other) {
                    if (cycle - last_interaction_cycle[other] < 20) {
                        can_interact <- false;
                    }
                }
                
                if (can_interact) {
                    float delta <- get_interaction_result(other);
                    happiness <- happiness + delta;
                    last_interaction_cycle[other] <- cycle;
                    
                    // Update social memory
                    if (not (social_memory.keys contains other)) {
                        social_memory[other] <- 0.5;
                    }
                    if (delta > 0) {
                        social_memory[other] <- social_memory[other] + 0.1;
                        if (social_memory[other] > 1.0) { social_memory[other] <- 1.0; }
                    } else if (delta < 0) {
                        social_memory[other] <- social_memory[other] - 0.1;
                        if (social_memory[other] < 0.0) { social_memory[other] <- 0.0; }
                    }
                }
            }
        } else {
            // Move to social venue (bar)
            if (current_state = "wandering" and length(Bar) > 0) {
                Bar b <- one_of(Bar);
                target_location <- b.location;
                current_state <- "going_to_venue";
                current_bar <- b;
            }
        }
    }
    
    action action_find_fun {
        total_bdi_actions <- total_bdi_actions + 1;
        
        if (current_state = "wandering") {
            // Choose venue based on type preference
            if (guest_type = 1 or guest_type = 4) {
                // Prefer stages
                if (length(Stage) > 0) {
                    Stage s <- Stage with_max_of(each.performance_quality);
                    target_location <- s.location;
                    current_state <- "going_to_venue";
                    current_stage <- s;
                }
            } else {
                // Prefer bars
                if (length(Bar) > 0) {
                    Bar b <- Bar with_max_of(each.quality);
                    target_location <- b.location;
                    current_state <- "going_to_venue";
                    current_bar <- b;
                }
            }
        }
    }
    
    action action_explore {
        total_bdi_actions <- total_bdi_actions + 1;
        
        // Leave bad venue
        if (current_bar != nil or current_stage != nil) {
            current_state <- "wandering";
            current_bar <- nil;
            current_stage <- nil;
        }
        
        // Try a random venue
        if (current_state = "wandering") {
            if (flip(0.5) and length(Bar) > 0) {
                Bar b <- one_of(Bar);
                target_location <- b.location;
                current_state <- "going_to_venue";
                current_bar <- b;
            } else if (length(Stage) > 0) {
                Stage s <- one_of(Stage);
                target_location <- s.location;
                current_state <- "going_to_venue";
                current_stage <- s;
            }
        }
    }
    
    action action_be_happy {
        total_bdi_actions <- total_bdi_actions + 1;
        
        // Meta-action: analyze situation and add appropriate desires
        if (happiness < 0.4 and not (my_desires contains "find_fun")) {
            my_desires <- my_desires + "find_fun";
        }
        
        if (happiness > 0.7 and sociability > 0.6 and not (my_desires contains "socialize")) {
            my_desires <- my_desires + "socialize";
        }
    }
    
    // ========================================================================
    // REGULAR BEHAVIORS (NON-BDI)
    // ========================================================================
    
    reflex live {
        if (fipa_cooldown > 0) { fipa_cooldown <- fipa_cooldown - 1; }
        
        energy <- energy - 0.002;
        if (energy < 0.0) { energy <- 0.0; }
        
        float decay_rate <- 0.005;
        if (guest_type = 2 or guest_type = 3) { decay_rate <- 0.010; }
        happiness <- happiness - decay_rate;
        
        if (happiness < 0.0) { happiness <- 0.0; }
        if (happiness > 1.0) { happiness <- 1.0; }
    }
    
    reflex wander when: current_state = "wandering" and current_intention = nil {
        float my_speed <- 1.0 + sociability;
        if (guest_type = 1) { my_speed <- 0.6; }
        if (guest_type = 2) { my_speed <- 1.8; }
        do wander amplitude: 30.0 speed: my_speed;
    }
    
    reflex move_to_target when: current_state = "going_to_venue" {
        if (target_location != nil) {
            do goto target: target_location speed: 1.5;
            if (self distance_to target_location < 3.0) {
                current_state <- "at_venue";
                time_at_venue <- 0;
            }
        }
    }
    
    reflex venue_behavior when: current_state = "at_venue" {
        time_at_venue <- time_at_venue + 1;
        
        float reward <- 0.0;
        if (current_bar != nil) {
            float exp <- current_bar.quality + rnd(-0.1, 0.1);
            if (guest_type = 1) { exp <- exp * 0.7; }
            if (guest_type = 4) { exp <- exp * 1.2; }
            reward <- (exp - 0.5) * 0.02;
        } else if (current_stage != nil) {
            float exp <- current_stage.performance_quality + rnd(-0.1, 0.1);
            if (guest_type = 2) { exp <- exp * 1.3; }
            if (guest_type = 5) { exp <- exp * 1.2; }
            reward <- (exp - 0.5) * 0.015;
        }
        
        happiness <- happiness + reward;
        
        int stay <- 30 + int(sociability * 40);
        if (time_at_venue > stay or flip(0.01)) {
            current_state <- "wandering";
            current_bar <- nil;
            current_stage <- nil;
        }
    }
    
    // INTERACTION LOGIC
    float get_interaction_result(Guest other) {
        string interaction_type <- "neutral";
        
        if (guest_type = 1) {
            if (other.guest_type = 1) { interaction_type <- "positive"; }
            else if (other.guest_type = 2) { if (flip(0.6)) { interaction_type <- "positive"; } else { interaction_type <- "negative"; } }
            else if (other.guest_type = 3) { if (flip(0.4)) { interaction_type <- "positive"; } else { interaction_type <- "neutral"; } }
            else if (other.guest_type = 4) { interaction_type <- "neutral"; }
            else if (other.guest_type = 5) { interaction_type <- "positive"; }
        } else if (guest_type = 2) {
            if (other.guest_type = 1) { if (flip(0.7)) { interaction_type <- "positive"; } else { interaction_type <- "negative"; } }
            else if (other.guest_type = 2) { if (flip(0.8)) { interaction_type <- "positive"; } else { interaction_type <- "conflict"; } }
            else if (other.guest_type = 3) { interaction_type <- "positive"; }
            else if (other.guest_type = 4) { if (flip(0.5)) { interaction_type <- "neutral"; } else { interaction_type <- "negative"; } }
            else if (other.guest_type = 5) { interaction_type <- "neutral"; }
        } else if (guest_type = 3) {
            if (other.guest_type = 1) { if (flip(0.6)) { interaction_type <- "positive"; } else { interaction_type <- "neutral"; } }
            else if (other.guest_type = 2) { interaction_type <- "positive"; }
            else if (other.guest_type = 3) { if (flip(0.85)) { interaction_type <- "positive"; } else { interaction_type <- "conflict"; } }
            else if (other.guest_type = 4) { if (flip(0.5)) { interaction_type <- "positive"; } else { interaction_type <- "neutral"; } }
            else if (other.guest_type = 5) { interaction_type <- "neutral"; }
        } else if (guest_type = 4) {
            if (other.guest_type = 1) { interaction_type <- "neutral"; }
            else if (other.guest_type = 2) { if (flip(0.4)) { interaction_type <- "positive"; } else { interaction_type <- "negative"; } }
            else if (other.guest_type = 3) { if (flip(0.5)) { interaction_type <- "positive"; } else { interaction_type <- "neutral"; } }
            else if (other.guest_type = 4) { if (flip(0.7)) { interaction_type <- "positive"; } else { interaction_type <- "neutral"; } }
            else if (other.guest_type = 5) { if (flip(0.3)) { interaction_type <- "negative"; } else { interaction_type <- "neutral"; } }
        } else if (guest_type = 5) {
            if (other.guest_type = 1) { interaction_type <- "positive"; }
            else if (other.guest_type = 2) { if (flip(0.6)) { interaction_type <- "positive"; } else { interaction_type <- "neutral"; } }
            else if (other.guest_type = 3) { interaction_type <- "neutral"; }
            else if (other.guest_type = 4) { interaction_type <- "neutral"; }
            else if (other.guest_type = 5) { if (flip(0.7)) { interaction_type <- "positive"; } else { interaction_type <- "neutral"; } }
        }
        
        if (interaction_type = "conflict" and flip(risk_aversion)) {
            interaction_type <- "negative";
        }
        
        float delta <- 0.0;
        
        if (interaction_type = "positive") {
            delta <- 0.03 * (1 + sociability);
            total_positive_interactions <- total_positive_interactions + 1;
            ask other { happiness <- happiness + (0.03 * (1 + sociability)); }
        } else if (interaction_type = "neutral") {
            delta <- rnd(-0.005, 0.01);
        } else if (interaction_type = "negative") {
            delta <- -0.02 * (1 - risk_aversion);
            total_negative_interactions <- total_negative_interactions + 1;
            ask other { happiness <- happiness - (0.02 * (1 - risk_aversion)); }
        } else if (interaction_type = "conflict") {
            delta <- -0.05 * (1 - risk_aversion);
            total_negative_interactions <- total_negative_interactions + 1;
            ask other { happiness <- happiness - (0.05 * (1 - risk_aversion)); }
        }
        
        return delta;
    }
    
    reflex receive_fipa_messages when: !empty(informs) {
        loop msg over: informs {
            // Process FIPA messages
        }
    }
    
    // ========================================================================
    // VISUALIZATION
    // ========================================================================
    
    aspect default {
        rgb base_color <- type_colors[guest_type - 1];
        float intensity <- 0.5 + happiness * 0.5;
        rgb display_color <- rgb(int(base_color.red * intensity), int(base_color.green * intensity), int(base_color.blue * intensity));
        
        draw circle(2.5) color: display_color border: #black;
        draw string(guest_type) color: #black font: font("Arial", 8, #bold) at: location + {0, -3};
        
        draw rectangle(4, 0.8) color: #red at: location + {0, 4};
        draw rectangle(4 * happiness, 0.8) color: #green at: location + {-2 + 2*happiness, 4};
    }
    
    aspect bdi {
        rgb base_color <- type_colors[guest_type - 1];
        float intensity <- 0.5 + happiness * 0.5;
        rgb display_color <- rgb(int(base_color.red * intensity), int(base_color.green * intensity), int(base_color.blue * intensity));
        
        draw circle(3) color: display_color border: #black;
        
        // Show current INTENTION (most important for BDI)
        if (current_intention != nil) {
            draw current_intention color: #white font: font("Arial", 6, #bold) at: location + {0, -7};
        }
        
        // Show number of beliefs and desires
        draw ("B:" + length(my_beliefs) + " D:" + length(my_desires)) color: #cyan font: font("Arial", 5, #plain) at: location + {0, 7};
    }
}

experiment FestivalBDI type: gui {
    
    output {
        display "Festival Map - BDI Agents" type: java2D {
            species Bar aspect: default;
            species Stage aspect: default;
            species Guest aspect: bdi;
        }
        
        display "Happiness" refresh: every(5#cycles) {
            chart "Global Average Happiness" type: series {
                data "Avg Happiness" value: global_avg_happiness color: #blue;
                data "Target (0.6)" value: 0.6 color: #gray;
            }
        }
        
        display "Interactions" refresh: every(5#cycles) {
            chart "Social Interactions" type: series {
                data "Positive" value: total_positive_interactions color: #green;
                data "Negative" value: total_negative_interactions color: #red;
            }
        }
        
        display "BDI System Activity" refresh: every(5#cycles) {
            chart "BDI Components" type: series {
                data "Actions Executed" value: total_bdi_actions color: #orange;
                data "Beliefs Updated" value: total_belief_updates color: #cyan;
                data "Intentions Changed" value: total_intention_changes color: #purple;
            }
        }
        
        display "Happiness by Type" refresh: every(10#cycles) {
            chart "Average Happiness by Guest Type" type: histogram {
                data "Elderly" value: (Guest where (each.guest_type = 1)) mean_of (each.happiness) color: #gray;
                data "Child" value: (Guest where (each.guest_type = 2)) mean_of (each.happiness) color: #yellow;
                data "Student" value: (Guest where (each.guest_type = 3)) mean_of (each.happiness) color: #blue;
                data "Worker" value: (Guest where (each.guest_type = 4)) mean_of (each.happiness) color: #brown;
                data "Couple" value: (Guest where (each.guest_type = 5)) mean_of (each.happiness) color: #pink;
            }
        }
        
        display "BDI Desires Distribution" refresh: every(10#cycles) {
            chart "Average Desires per Guest Type" type: histogram {
                data "Elderly" value: (Guest where (each.guest_type = 1)) mean_of (length(each.my_desires)) color: #gray;
                data "Child" value: (Guest where (each.guest_type = 2)) mean_of (length(each.my_desires)) color: #yellow;
                data "Student" value: (Guest where (each.guest_type = 3)) mean_of (length(each.my_desires)) color: #blue;
                data "Worker" value: (Guest where (each.guest_type = 4)) mean_of (length(each.my_desires)) color: #brown;
                data "Couple" value: (Guest where (each.guest_type = 5)) mean_of (length(each.my_desires)) color: #pink;
            }
        }
        
        monitor "Cycle" value: cycle;
        monitor "Avg Happiness" value: global_avg_happiness with_precision 3;
        monitor "Positive Interactions" value: total_positive_interactions;
        monitor "Conflicts" value: total_negative_interactions;
        monitor "--- BDI METRICS ---" value: "";
        monitor "BDI Actions" value: total_bdi_actions;
        monitor "Belief Updates" value: total_belief_updates;
        monitor "Intention Changes" value: total_intention_changes;
    }
}
