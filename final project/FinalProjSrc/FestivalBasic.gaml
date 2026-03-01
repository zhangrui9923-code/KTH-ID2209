
model FestivalSimulation

global {
   
    // Number of agents
    int num_guests <- 50;
    int num_bars <- 3;
    int num_stages <- 2;
    
    // FIPA toggle 
    bool use_fipa <- true;
    
    // Simulation parameters
    float interaction_distance <- 5.0;
    float venue_radius <- 8.0;
    
    // Environment size
    float env_size <- 100.0;
    geometry shape <- square(env_size);
    
   
    float global_avg_happiness <- 0.5;
    int total_positive_interactions <- 0;
    int total_negative_interactions <- 0;
    int total_fipa_messages_sent <- 0;
    float global_avg_bar_reputation <- 0.5;
    
    // ========================================================================
    // GUEST TYPE DEFINITIONS
    // ========================================================================
    // Type 1: Elderly - calm, risk-averse, prefers quiet stages
    // Type 2: Child - energetic, low risk awareness, needs supervision
    // Type 3: Student - social, budget-conscious, loves both venues
    // Type 4: Office Worker - moderate, stressed, seeks relaxation
    // Type 5: Couple - romantic, prefer being together, selective interactions
    
    list<string> type_names <- ["Elderly", "Child", "Student", "Office Worker", "Couple"];
    
    // Colors for each type 
    list<rgb> type_colors <- [#gray, #yellow, #blue, #brown, #pink];
    
    // ========================================================================
    // INITIALIZATION
    // ========================================================================
    
    init {
        write "============================================";
        write "FESTIVAL SIMULATION STARTING";
        write "FIPA Communication: " + (use_fipa ? "ENABLED" : "DISABLED");
        write "Number of guests: " + string(num_guests);
        write "============================================";
        
        // Create bars at strategic locations
        create Bar number: num_bars {
            location <- {rnd(20.0, 80.0), rnd(20.0, 80.0)};
            bar_name <- "Bar_" + string(int(self));
            quality <- rnd(0.3, 0.9);
        }
        
        // Create stages at strategic locations
        create Stage number: num_stages {
            location <- {rnd(20.0, 80.0), rnd(20.0, 80.0)};
            stage_name <- "Stage_" + string(int(self));
            performance_quality <- rnd(0.4, 1.0);
        }
        
        // Create 50+ guests with distributed types
        create Guest number: num_guests {
            location <- {rnd(env_size), rnd(env_size)};
            
            // Assign type (roughly equal distribution)
            guest_type <- rnd(1, 5);
            
            // Initialize 3 personality traits based on type
            if (guest_type = 1) { // Elderly
                sociability <- rnd(0.3, 0.5);      // Low-moderate sociability
                risk_aversion <- rnd(0.7, 0.95);   // High risk aversion
                trust <- rnd(0.6, 0.85);           // Relatively trusting
            } else if (guest_type = 2) { // Child
                sociability <- rnd(0.7, 1.0);      // Very social and energetic
                risk_aversion <- rnd(0.05, 0.3);   // Low risk awareness
                trust <- rnd(0.7, 0.95);           // Very trusting
            } else if (guest_type = 3) { // Student
                sociability <- rnd(0.6, 0.9);      // High sociability
                risk_aversion <- rnd(0.2, 0.5);    // Moderate risk tolerance
                trust <- rnd(0.5, 0.8);            // Moderate trust
            } else if (guest_type = 4) { // Office Worker
                sociability <- rnd(0.4, 0.7);      // Moderate sociability
                risk_aversion <- rnd(0.5, 0.8);    // Moderate-high risk aversion
                trust <- rnd(0.3, 0.6);            // Lower trust (skeptical)
            } else { // Type 5: Couple
                sociability <- rnd(0.3, 0.6);      // Lower sociability (focused on partner)
                risk_aversion <- rnd(0.4, 0.7);    // Moderate risk aversion
                trust <- rnd(0.5, 0.8);            // Moderate trust
            }
            
            // Initialize reputation map for all bars
            loop b over: Bar {
                bar_reputation[b] <- 0.5;
            }
        }
        
        write "Initialization complete. " + string(length(Guest)) + " guests created.";
    }
    
    // ========================================================================
    // GLOBAL REFLEX: Update metrics each cycle
    // ========================================================================
    
    reflex update_global_metrics {
        // Calculate average happiness
        if (length(Guest) > 0) {
            float sum_happiness <- 0.0;
            ask Guest {
                sum_happiness <- sum_happiness + happiness;
            }
            global_avg_happiness <- sum_happiness / length(Guest);
        }
        
        // Calculate average bar reputation across all guests
        float total_rep <- 0.0;
        int count <- 0;
        ask Guest {
            loop b over: Bar {
                total_rep <- total_rep + bar_reputation[b];
                count <- count + 1;
            }
        }
        if (count > 0) {
            global_avg_bar_reputation <- total_rep / count;
        }
    }
    
    // Periodic status report
    reflex report when: (cycle mod 100) = 0 and cycle > 0 {
        write "--- Cycle " + string(cycle) + " Report ---";
        write "  Average Happiness: " + string(global_avg_happiness with_precision 3);
        write "  Positive Interactions: " + string(total_positive_interactions);
        write "  Conflicts: " + string(total_negative_interactions);
        write "  FIPA Messages Sent: " + string(total_fipa_messages_sent);
    }
}

// ============================================================================
// VENUE SPECIES: BAR
// ============================================================================

species Bar {
    string bar_name;
    float quality;
    int visitors_today <- 0;
    
    aspect default {
        draw square(6) color: #brown border: #black;
        draw bar_name color: #white font: font("Arial", 10, #bold) at: location + {0, -4};
        draw string(visitors_today) color: #yellow font: font("Arial", 8, #plain) at: location + {0, 4};
    }
}

// ============================================================================
// VENUE SPECIES: STAGE
// ============================================================================

species Stage {
    string stage_name;
    float performance_quality;
    int audience_count <- 0;
    
    // Performances change periodically
    reflex change_performance when: (cycle mod 50) = 0 {
        performance_quality <- rnd(0.3, 1.0);
    }
    
    aspect default {
        draw triangle(8) color: #purple border: #black;
        draw stage_name color: #white font: font("Arial", 10, #bold) at: location + {0, -5};
        draw string(audience_count) color: #cyan font: font("Arial", 8, #plain) at: location + {0, 5};
    }
}

// ============================================================================
// GUEST SPECIES - Main agent with FIPA skill
// ============================================================================

species Guest skills: [moving, fipa] {
    
    // ========================================================================
    // GUEST ATTRIBUTES
    // ========================================================================
    
    // Type (1-5) determines base behavior patterns
    int guest_type;
    
    // THREE PERSONALITY TRAITS
    float sociability;      // How likely to interact with others
    float risk_aversion;    // How cautious in decisions
    float trust;            // How much to believe others' information
    
    // Internal state
    float happiness <- 0.5;
    point target_location;
    Bar current_bar;
    Stage current_stage;
    bool at_venue <- false;
    
    // Reputation map for bars (updated via FIPA)
    map<Bar, float> bar_reputation;
    
    // Interaction cooldowns
    map<Guest, int> last_interaction_cycle;
    int fipa_cooldown <- 0;
    
    // Movement state
    string current_state <- "wandering";
    int time_at_venue <- 0;
    
    // ========================================================================
    // MAIN BEHAVIOR REFLEX
    // ========================================================================
    
    reflex live {
        // Decrease cooldowns
        if (fipa_cooldown > 0) {
            fipa_cooldown <- fipa_cooldown - 1;
        }
        
        // State machine for behavior
        if (current_state = "wandering") {
            do wander_behavior;
        } else if (current_state = "going_to_venue") {
            do move_to_target;
        } else if (current_state = "at_venue") {
            do venue_behavior;
        }
        
        // Clamp happiness
        if (happiness < 0.0) { happiness <- 0.0; }
        if (happiness > 1.0) { happiness <- 1.0; }
    }
    
    // ========================================================================
    // WANDERING BEHAVIOR
    // ========================================================================
    
    action wander_behavior {
        // Random movement - speed varies by type
        float my_speed <- 1.0 + sociability;
        if (guest_type = 1) { my_speed <- 0.6; }  // Elderly move slower
        if (guest_type = 2) { my_speed <- 1.8; }  // Children move faster
        
        do wander amplitude: 30.0 speed: my_speed;
        
        // Decision to go to a venue based on type and traits
        if (flip(0.02 + sociability * 0.03)) {
            do choose_venue;
        }
        
        // Check for nearby guests to interact with
        do check_interactions;
    }
    
    // ========================================================================
    // VENUE SELECTION - Uses reputation
    // ========================================================================
    
    action choose_venue {
        Bar chosen_bar <- nil;
        Stage chosen_stage <- nil;
        float best_score <- -1.0;
        
        // Type-based preference for venues
        float bar_preference <- 0.5;
        float stage_preference <- 0.5;
        
        if (guest_type = 1) {        // Elderly: prefer quiet stages
            bar_preference <- 0.2; 
            stage_preference <- 0.8; 
        } else if (guest_type = 2) { // Child: slightly prefer stages (shows/performances)
            bar_preference <- 0.3; 
            stage_preference <- 0.7; 
        } else if (guest_type = 3) { // Student: like both, slight bar preference
            bar_preference <- 0.6; 
            stage_preference <- 0.4; 
        } else if (guest_type = 4) { // Office Worker: prefer bars (drinks to relax)
            bar_preference <- 0.7; 
            stage_preference <- 0.3; 
        } else if (guest_type = 5) { // Couple: balanced, romantic spots
            bar_preference <- 0.5; 
            stage_preference <- 0.5; 
        }
        
        // Evaluate bars
        if (flip(bar_preference)) {
            loop b over: Bar {
                float rep <- bar_reputation[b];
                float dist <- self distance_to b;
                float dist_factor <- 1.0 - (dist / 150.0);
                if (dist_factor < 0) { dist_factor <- 0.0; }
                float score <- rep * 0.6 + dist_factor * 0.3 + rnd(0.1);
                
                // Risk-averse guests prefer known good places
                if (risk_aversion > 0.5 and rep < 0.4) {
                    score <- score * 0.5;
                }
                
                // Elderly avoid crowded bars
                if (guest_type = 1 and b.visitors_today > 5) {
                    score <- score * 0.3;
                }
                
                if (score > best_score) {
                    best_score <- score;
                    chosen_bar <- b;
                    chosen_stage <- nil;
                }
            }
        }
        
        // Evaluate stages
        if (chosen_bar = nil or flip(stage_preference * 0.5)) {
            loop s over: Stage {
                float dist <- self distance_to s;
                float dist_factor <- 1.0 - (dist / 150.0);
                if (dist_factor < 0) { dist_factor <- 0.0; }
                float score <- s.performance_quality * 0.5 + dist_factor * 0.3 + rnd(0.2);
                
                // Children love high-quality performances
                if (guest_type = 2 and s.performance_quality > 0.7) {
                    score <- score * 1.5;
                }
                
                if (score > best_score) {
                    best_score <- score;
                    chosen_stage <- s;
                    chosen_bar <- nil;
                }
            }
        }
        
        if (chosen_bar != nil) {
            target_location <- chosen_bar.location;
            current_bar <- chosen_bar;
            current_stage <- nil;
            current_state <- "going_to_venue";
        } else if (chosen_stage != nil) {
            target_location <- chosen_stage.location;
            current_stage <- chosen_stage;
            current_bar <- nil;
            current_state <- "going_to_venue";
        }
    }
    
    // ========================================================================
    // MOVEMENT TO TARGET
    // ========================================================================
    
    action move_to_target {
        if (target_location != nil) {
            do goto target: target_location speed: 1.5;
            
            float dist <- self distance_to target_location;
            if (dist < 3.0) {
                current_state <- "at_venue";
                time_at_venue <- 0;
                at_venue <- true;
                
                // Register arrival
                if (current_bar != nil) {
                    ask current_bar {
                        visitors_today <- visitors_today + 1;
                    }
                } else if (current_stage != nil) {
                    ask current_stage {
                        audience_count <- audience_count + 1;
                    }
                }
            }
        }
    }
    
    // ========================================================================
    // VENUE BEHAVIOR
    // ========================================================================
    
    action venue_behavior {
        time_at_venue <- time_at_venue + 1;
        
        // Experience the venue
        if (current_bar != nil) {
            float experience <- current_bar.quality + rnd(-0.1, 0.1);
            
            // Type-specific experience modifiers
            if (guest_type = 1) { // Elderly: less enjoyment at bars
                experience <- experience * 0.7;
            } else if (guest_type = 4) { // Office Worker: extra relaxation from drinks
                experience <- experience * 1.2;
            }
            
            happiness <- happiness + (experience - 0.5) * 0.02;
            
            // FIPA MESSAGE: Share bar experience with others
            if (use_fipa and fipa_cooldown = 0 and time_at_venue = 10) {
                do share_bar_experience(current_bar, experience);
            }
        } else if (current_stage != nil) {
            float experience <- current_stage.performance_quality + rnd(-0.1, 0.1);
            
            // Type-specific experience modifiers
            if (guest_type = 2) { // Child: loves performances
                experience <- experience * 1.3;
            } else if (guest_type = 5) { // Couple: romantic shows boost happiness
                experience <- experience * 1.2;
            }
            
            happiness <- happiness + (experience - 0.5) * 0.015;
        }
        
        // Check for interactions at venue
        do check_interactions;
        
        // Decide when to leave - varies by type
        int stay_duration <- 30 + int(sociability * 40) + int((1 - risk_aversion) * 20);
        if (guest_type = 1) { stay_duration <- stay_duration + 20; }  // Elderly stay longer once settled
        if (guest_type = 2) { stay_duration <- stay_duration - 15; }  // Children get bored faster
        if (guest_type = 5) { stay_duration <- stay_duration + 10; }  // Couples enjoy their time
        
        if (time_at_venue > stay_duration or flip(0.01)) {
            do leave_venue;
        }
    }
    
    // ========================================================================
    // FIPA MESSAGING: Share Bar Experience
    // ========================================================================
    
    action share_bar_experience(Bar b, float experience) {
        // Determine message type based on experience
        string rep_status;
        if (experience > 0.5) {
            rep_status <- "good";
        } else {
            rep_status <- "bad";
        }
        
        // Create message content as a list
        list<string> msg_content <- [b.bar_name, rep_status, string(experience)];
        
        // Select recipients based on guest type
        list<Guest> recipients <- [];
        int max_recipients <- 5;
        
        if (guest_type = 3) { max_recipients <- 15; }  // Students share with many friends
        if (guest_type = 4) { max_recipients <- 8; }   // Office workers share moderately
        if (guest_type = 1) { max_recipients <- 3; }   // Elderly share with fewer people
        if (guest_type = 5) { max_recipients <- 2; }   // Couples mostly talk to each other
        
        // Get nearby guests
        list<Guest> nearby <- (Guest where (each != self));
        nearby <- nearby sort_by (each distance_to self);
        
        int count <- 0;
        loop g over: nearby {
            if (count < max_recipients) {
                recipients <- recipients + g;
                count <- count + 1;
            }
        }
        
        // Send FIPA INFORM message
        if (length(recipients) > 0) {
            do start_conversation to: recipients performative: "inform" contents: msg_content;
            total_fipa_messages_sent <- total_fipa_messages_sent + 1;
            fipa_cooldown <- 30;
        }
    }
    
    // ========================================================================
    // FIPA MESSAGE RECEPTION
    // ========================================================================
    
    reflex receive_fipa_messages when: use_fipa and (length(informs) > 0) {
        loop msg over: informs {
            list content <- list(msg.contents);
            
            if (length(content) >= 3) {
                string received_bar_name <- string(content[0]);
                string rep_status <- string(content[1]);
                float sender_experience <- float(content[2]);
                
                // Find the bar being discussed
                Bar discussed_bar <- nil;
                loop b over: Bar {
                    if (b.bar_name = received_bar_name) {
                        discussed_bar <- b;
                    }
                }
                
                if (discussed_bar != nil) {
                    // UPDATE INTERNAL BELIEF based on trust trait
                    float current_rep <- bar_reputation[discussed_bar];
                    float message_rep;
                    if (rep_status = "good") {
                        message_rep <- sender_experience + 0.1;
                        if (message_rep > 1.0) { message_rep <- 1.0; }
                    } else {
                        message_rep <- sender_experience - 0.1;
                        if (message_rep < 0.0) { message_rep <- 0.0; }
                    }
                    
                    // Weighted update: trust determines how much to believe
                    float weight <- trust * 0.3;
                    float new_rep <- current_rep * (1 - weight) + message_rep * weight;
                    bar_reputation[discussed_bar] <- new_rep;
                    
                    // Type-specific reactions to information
                    if (guest_type = 4) { // Office Workers are skeptical
                        bar_reputation[discussed_bar] <- current_rep * 0.8 + new_rep * 0.2;
                    } else if (guest_type = 2) { // Children believe everything
                        bar_reputation[discussed_bar] <- current_rep * 0.3 + new_rep * 0.7;
                    } else if (guest_type = 1) { // Elderly are moderately trusting
                        bar_reputation[discussed_bar] <- current_rep * 0.6 + new_rep * 0.4;
                    }
                }
            }
        }
    }
    
    // ========================================================================
    // LEAVE VENUE
    // ========================================================================
    
    action leave_venue {
        if (current_bar != nil) {
            ask current_bar {
                visitors_today <- visitors_today - 1;
                if (visitors_today < 0) { visitors_today <- 0; }
            }
        } else if (current_stage != nil) {
            ask current_stage {
                audience_count <- audience_count - 1;
                if (audience_count < 0) { audience_count <- 0; }
            }
        }
        
        current_bar <- nil;
        current_stage <- nil;
        target_location <- nil;
        current_state <- "wandering";
        at_venue <- false;
    }
    
    // ========================================================================
    // GUEST-TO-GUEST INTERACTIONS
    // ========================================================================
    
    action check_interactions {
        // Find nearby guests
        list<Guest> nearby <- (Guest at_distance interaction_distance) where (each != self);
        
        loop other over: nearby {
            // Check cooldown
            bool on_cooldown <- false;
            if (last_interaction_cycle contains_key other) {
                if (cycle - last_interaction_cycle[other] < 20) {
                    on_cooldown <- true;
                }
            }
            
            if (not on_cooldown) {
                // INTERACTION DECISION based on BOTH types and traits
                bool will_interact <- false;
                string interaction_type <- "neutral";
                
                // Base interaction probability from sociability
                float interact_prob <- (sociability + other.sociability) / 2;
                
                // ================================================================
                // TYPE-BASED INTERACTION RULES
                // ================================================================
                
                if (guest_type = 1) { // Elderly
                    interact_prob <- interact_prob - 0.1;  // Less likely to initiate
                    if (other.guest_type = 1) {
                        interaction_type <- "positive";  // Elderly enjoy each other's company
                    } else if (other.guest_type = 2) {
                        if (flip(0.6)) { 
                            interaction_type <- "positive";  // Often enjoy watching children
                        } else { 
                            interaction_type <- "negative";  // Sometimes children are too noisy
                        }
                    } else if (other.guest_type = 3) {
                        if (flip(0.4)) { interaction_type <- "positive"; }  // Students can be respectful
                        else { interaction_type <- "neutral"; }
                    } else if (other.guest_type = 4) {
                        interaction_type <- "neutral";  // Polite but distant with workers
                    } else if (other.guest_type = 5) {
                        interaction_type <- "positive";  // Enjoy seeing happy couples
                    }
                    
                } else if (guest_type = 2) { // Child
                    interact_prob <- interact_prob + 0.2;  // Children interact a lot
                    if (other.guest_type = 1) {
                        if (flip(0.7)) { 
                            interaction_type <- "positive";  // Children like grandparent figures
                        } else { 
                            interaction_type <- "negative";  // May annoy elderly
                        }
                    } else if (other.guest_type = 2) {
                        if (flip(0.8)) { 
                            interaction_type <- "positive";  // Children play together
                        } else { 
                            interaction_type <- "conflict";  // Sometimes fight over toys/attention
                        }
                    } else if (other.guest_type = 3) {
                        interaction_type <- "positive";  // Students are often friendly to kids
                    } else if (other.guest_type = 4) {
                        if (flip(0.5)) { interaction_type <- "neutral"; }
                        else { interaction_type <- "negative"; }  // Workers may be impatient
                    } else if (other.guest_type = 5) {
                        interaction_type <- "neutral";  // Couples busy with each other
                    }
                    
                } else if (guest_type = 3) { // Student
                    interact_prob <- interact_prob + 0.15;
                    if (other.guest_type = 1) {
                        if (flip(0.6)) { interaction_type <- "positive"; }  // Respectful to elderly
                        else { interaction_type <- "neutral"; }
                    } else if (other.guest_type = 2) {
                        interaction_type <- "positive";  // Friendly to children
                    } else if (other.guest_type = 3) {
                        if (flip(0.85)) { 
                            interaction_type <- "positive";  // Students party together!
                        } else { 
                            interaction_type <- "conflict";  // Sometimes compete/argue
                        }
                    } else if (other.guest_type = 4) {
                        if (flip(0.5)) { interaction_type <- "positive"; }  // Can relate to workers
                        else { interaction_type <- "neutral"; }
                    } else if (other.guest_type = 5) {
                        interaction_type <- "neutral";  // Don't disturb couples
                    }
                    
                } else if (guest_type = 4) { // Office Worker
                    interact_prob <- interact_prob - 0.05;  // Tired, less social
                    if (other.guest_type = 1) {
                        interaction_type <- "neutral";  // Polite but reserved
                    } else if (other.guest_type = 2) {
                        if (flip(0.4)) { interaction_type <- "positive"; }  // Some like kids
                        else { interaction_type <- "negative"; }  // Many are annoyed
                    } else if (other.guest_type = 3) {
                        if (flip(0.5)) { interaction_type <- "positive"; }  // Remember being young
                        else { interaction_type <- "neutral"; }
                    } else if (other.guest_type = 4) {
                        if (flip(0.7)) { 
                            interaction_type <- "positive";  // Bond over work stress
                        } else { 
                            interaction_type <- "neutral"; 
                        }
                    } else if (other.guest_type = 5) {
                        if (flip(0.3)) { interaction_type <- "negative"; }  // Jealous of couples
                        else { interaction_type <- "neutral"; }
                    }
                    
                } else if (guest_type = 5) { // Couple
                    interact_prob <- interact_prob - 0.2;  // Focused on each other
                    if (other.guest_type = 1) {
                        interaction_type <- "positive";  // Respectful to elderly
                    } else if (other.guest_type = 2) {
                        if (flip(0.6)) { interaction_type <- "positive"; }  // Think kids are cute
                        else { interaction_type <- "neutral"; }
                    } else if (other.guest_type = 3) {
                        interaction_type <- "neutral";  // Polite but focused on partner
                    } else if (other.guest_type = 4) {
                        interaction_type <- "neutral";
                    } else if (other.guest_type = 5) {
                        if (flip(0.7)) { 
                            interaction_type <- "positive";  // Couples bond with couples
                        } else { 
                            interaction_type <- "neutral"; 
                        }
                    }
                }
                
                // Risk aversion reduces conflict chance
                if (interaction_type = "conflict" and flip(risk_aversion)) {
                    interaction_type <- "negative";
                }
                
                // Final decision
                will_interact <- flip(interact_prob);
                
                if (will_interact) {
                    do execute_interaction(other, interaction_type);
                    last_interaction_cycle[other] <- cycle;
                }
            }
        }
    }
    
    // ========================================================================
    // EXECUTE INTERACTION
    // ========================================================================
    
    action execute_interaction(Guest other, string interaction_type) {
        float happiness_delta <- 0.0;
        float other_delta <- 0.0;
        
        if (interaction_type = "positive") {
            happiness_delta <- 0.03 * (1 + sociability);
            other_delta <- 0.03 * (1 + other.sociability);
            total_positive_interactions <- total_positive_interactions + 1;
        } else if (interaction_type = "neutral") {
            happiness_delta <- rnd(-0.005, 0.01);
            other_delta <- rnd(-0.005, 0.01);
        } else if (interaction_type = "negative") {
            happiness_delta <- -0.02 * (1 - risk_aversion);
            other_delta <- -0.02 * (1 - other.risk_aversion);
            total_negative_interactions <- total_negative_interactions + 1;
        } else if (interaction_type = "conflict") {
            happiness_delta <- -0.05 * (1 - risk_aversion);
            other_delta <- -0.05 * (1 - other.risk_aversion);
            total_negative_interactions <- total_negative_interactions + 1;
        }
        
        // Apply happiness changes
        happiness <- happiness + happiness_delta;
        ask other {
            happiness <- happiness + other_delta;
        }
    }
    
    // ========================================================================
    // VISUALIZATION
    // ========================================================================
    
    aspect default {
        rgb my_color <- type_colors[guest_type - 1];
        
        // Color intensity based on happiness
        float intensity <- 0.5 + happiness * 0.5;
        int r <- int(my_color.red * intensity);
        int g <- int(my_color.green * intensity);
        int b <- int(my_color.blue * intensity);
        if (r > 255) { r <- 255; }
        if (g > 255) { g <- 255; }
        if (b > 255) { b <- 255; }
        rgb display_color <- rgb(r, g, b);
        
        draw circle(2) color: display_color border: #black;
        draw string(guest_type) color: #black font: font("Arial", 8, #bold) at: location + {0, -3};
    }
    
    aspect detailed {
        rgb my_color <- type_colors[guest_type - 1];
        float intensity <- 0.5 + happiness * 0.5;
        int r <- int(my_color.red * intensity);
        int g <- int(my_color.green * intensity);
        int b <- int(my_color.blue * intensity);
        if (r > 255) { r <- 255; }
        if (g > 255) { g <- 255; }
        if (b > 255) { b <- 255; }
        rgb display_color <- rgb(r, g, b);
        
        draw circle(2.5) color: display_color border: #black;
        draw string(guest_type) color: #black font: font("Arial", 8, #bold) at: location + {0, -3};
        
        // Happiness bar
        draw rectangle(4, 0.8) color: #red at: location + {0, 4};
        draw rectangle(4 * happiness, 0.8) color: #green at: location + {-2 + 2*happiness, 4};
    }
}

// ============================================================================
// EXPERIMENTS
// ============================================================================

experiment FestivalMain type: gui {
    // Parameters exposed in UI
    parameter "Enable FIPA Communication" var: use_fipa <- true;
    parameter "Number of Guests" var: num_guests <- 50 min: 10 max: 200;
    parameter "Number of Bars" var: num_bars <- 3 min: 1 max: 10;
    parameter "Number of Stages" var: num_stages <- 2 min: 1 max: 5;
    parameter "Interaction Distance" var: interaction_distance <- 5.0 min: 1.0 max: 20.0;
    
    output {
        // Main visualization
        display "Festival Map" type: java2D {
            species Bar aspect: default;
            species Stage aspect: default;
            species Guest aspect: detailed;
        }
        
        // Chart 1: Global Average Happiness over time
        display "Happiness Chart" refresh: every(5#cycles) {
            chart "Global Average Happiness" type: series x_label: "Cycle" y_label: "Happiness" {
                data "Average Happiness" value: global_avg_happiness color: #blue marker: false;
                data "Target (0.6)" value: 0.6 color: #gray;
            }
        }
        
        // Chart 2: Interactions and Conflicts
        display "Interactions Chart" refresh: every(5#cycles) {
            chart "Interactions Over Time" type: series x_label: "Cycle" y_label: "Count" {
                data "Positive Interactions" value: total_positive_interactions color: #green marker: false;
                data "Conflicts" value: total_negative_interactions color: #red marker: false;
            }
        }
        
        // FIPA messages chart
        display "FIPA Messages" refresh: every(5#cycles) {
            chart "FIPA Communication" type: series x_label: "Cycle" y_label: "Messages" {
                data "Total FIPA Messages" value: total_fipa_messages_sent color: #purple marker: false;
            }
        }
        
        // Pie chart of guest types
        display "Guest Type Distribution" refresh: every(50#cycles) {
            chart "Guest Types" type: pie {
                data "Type 1: Elderly" value: length(Guest where (each.guest_type = 1)) color: #gray;
                data "Type 2: Child" value: length(Guest where (each.guest_type = 2)) color: #yellow;
                data "Type 3: Student" value: length(Guest where (each.guest_type = 3)) color: #blue;
                data "Type 4: Office Worker" value: length(Guest where (each.guest_type = 4)) color: #brown;
                data "Type 5: Couple" value: length(Guest where (each.guest_type = 5)) color: #pink;
            }
        }
        
        // Happiness by type
        display "Happiness by Type" refresh: every(10#cycles) {
            chart "Average Happiness by Guest Type" type: histogram x_label: "Type" y_label: "Happiness" {
                data "Elderly" value: (Guest where (each.guest_type = 1)) mean_of each.happiness color: #gray;
                data "Child" value: (Guest where (each.guest_type = 2)) mean_of each.happiness color: #yellow;
                data "Student" value: (Guest where (each.guest_type = 3)) mean_of each.happiness color: #blue;
                data "Worker" value: (Guest where (each.guest_type = 4)) mean_of each.happiness color: #brown;
                data "Couple" value: (Guest where (each.guest_type = 5)) mean_of each.happiness color: #pink;
            }
        }
        
        // Monitors
        monitor "Cycle" value: cycle;
        monitor "Average Happiness" value: global_avg_happiness with_precision 3;
        monitor "Positive Interactions" value: total_positive_interactions;
        monitor "Conflicts" value: total_negative_interactions;
        monitor "FIPA Messages Sent" value: total_fipa_messages_sent;
        monitor "Avg Bar Reputation" value: global_avg_bar_reputation with_precision 3;
        monitor "FIPA Enabled" value: use_fipa;
    }
}

// ============================================================================
// COMPARISON EXPERIMENT: Run with FIPA OFF
// ============================================================================

experiment FestivalNoFIPA type: gui {
    parameter "Enable FIPA Communication" var: use_fipa <- false;
    parameter "Number of Guests" var: num_guests <- 50;
    parameter "Number of Bars" var: num_bars <- 3;
    parameter "Number of Stages" var: num_stages <- 2;
    
    output {
        display "Festival Map (No FIPA)" type: java2D {
            species Bar aspect: default;
            species Stage aspect: default;
            species Guest aspect: detailed;
        }
        
        display "Happiness Chart (No FIPA)" refresh: every(5#cycles) {
            chart "Global Average Happiness (FIPA OFF)" type: series x_label: "Cycle" y_label: "Happiness" {
                data "Average Happiness" value: global_avg_happiness color: #red marker: false;
                data "Target (0.6)" value: 0.6 color: #gray;
            }
        }
        
        display "Interactions Chart (No FIPA)" refresh: every(5#cycles) {
            chart "Interactions (FIPA OFF)" type: series x_label: "Cycle" y_label: "Count" {
                data "Positive Interactions" value: total_positive_interactions color: #green marker: false;
                data "Conflicts" value: total_negative_interactions color: #red marker: false;
            }
        }
        
        monitor "Cycle" value: cycle;
        monitor "Average Happiness" value: global_avg_happiness with_precision 3;
        monitor "Positive Interactions" value: total_positive_interactions;
        monitor "Conflicts" value: total_negative_interactions;
        monitor "FIPA Messages Sent" value: total_fipa_messages_sent;
        monitor "FIPA Enabled" value: use_fipa;
    }
}

// ============================================================================
// BATCH EXPERIMENT for Statistical Comparison
// ============================================================================

experiment BatchComparison type: batch repeat: 5 until: cycle >= 1000 {
    parameter "FIPA" var: use_fipa among: [true, false];
    
    reflex end_of_run {
        write "Run complete - FIPA: " + string(use_fipa) + " Final Happiness: " + string(global_avg_happiness);
    }
}
