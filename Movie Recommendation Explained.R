#---------#0 Basic Steps------------
# Load relevant packages
library(arules)
library(arulesViz)
library(dplyr)
library(tidyr)
library(ggplot2)
library(igraph)
library(reshape2)
library(proxy)

# Load the datasets
movies <- read.csv("/Users/ashishalexander/Downloads/Data Analytics Assignment/movie ml-latest-small/movies.csv", stringsAsFactors = FALSE)
ratings <- read.csv("/Users/ashishalexander/Downloads/Data Analytics Assignment/movie ml-latest-small/ratings.csv", stringsAsFactors = FALSE)


#---------#1 Frequent Genre Combination------------

# Step 1: Preparing the genre data
movies_genres <- movies %>% 
  # Pipe operator -> Takes "movies" df as input and passes it on
  mutate(genres = ifelse(genres == "(no genres listed)", NA, genres)) %>% 
  # Modifies an existing column
  separate_rows(genres, sep = "\\|") %>% 
  # Escaped pipe symbol (\|) -> Expands it into multiple rows.
  group_by(movieId) %>% 
  # Groups the data by movieId.
  summarise(genres_list = list(genres), .groups = 'keep') 
  # Creates new column as list of individual genres (split earlier) for each movie
  # While "keep" preserves the original grouping structure from the group_by step.

# Step 2: Creating a transaction object from genres
trans_list <- lapply(movies_genres$genres_list, function(x) paste(x, collapse = ","))
  # -> lapply: This function iterates over a list (genres_list) 
  # -> function: This takes a list of genres ('x') and concatenates them into a single comma-separated string.

trans <- as(trans_list, "transactions")
  # Appears in a sparse matrix format by transforming data into the "transactions" format
  # transactions Action Comedy Drama Horror Mystery Romance Sci-Fi Thriller Adventure
  # 1            TRUE  FALSE FALSE  FALSE   FALSE   FALSE   TRUE    FALSE     TRUE 
  # 2            FALSE  TRUE  FALSE  FALSE   FALSE   TRUE  FALSE    FALSE     FALSE

# Step 3: Perform Apriori algorithm for frequent itemsets (genres in this case)
frequent_genres <- apriori(trans, parameter = list(supp = 0.01, conf=0.8, target = "frequent itemsets"))
  # supp: Sets minimum support threshold which measures how frequently an itemset (genre combination) appears across all transactions (movies).
    # A setting of 0.01 means itemsets must appear in at least 1% of the movies to be considered frequent.
    # Why this: Cast a reasonably wide net which helps identify both highly popular pairings and some potentially niche combinations,
  # conf: Sets minimum confidence threshold which measures the likelihood that a particular genre combination occurs together.
    # A value of 0.8 implies that if a subset of genres appears in a movie, there's at least an 80% chance that the other genres in the combination will also appear.
    # Why this: Focusing on genre combinations with relatively strong predictive power
  # target= "frequent itemset" -> focus on discovering sets of items (genres in this case) that appear together frequently across the transactions (movies).
  # Step by step explanation of what is happening by example: 
    # Imagine a grocery store transaction dataset where each transaction represents a customer's shopping basket.
      # 1. Identifying frequent single items (e.g., Bread appearing frequently in many transactions).
      # 2. Combining these frequent single items into candidate itemsets (e.g., {Bread, Butter}).
      # 3. Evaluating the support and confidence of these candidate itemsets. Only those that meet the minimum thresholds (set by the user) are retained as frequent itemsets.
      # 4. Iteratively building larger itemsets by combining existing frequent itemsets and evaluating them again. This process continues until no new frequent itemsets can be found.

# Step 4: Extracting genre combinations directly from itemsets
genre_combinations <- labels(frequent_genres)
  # Extracts the "labels" of the frequent itemsets
  # How it looks
    # genre_combinations
      # [1] "{Comedy,Crime}"         "{Drama,War}"            "{Crime,Drama,Thriller}" "{Crime,Drama}"         
      # [5] "{Horror,Thriller}"      "{Horror}"               "{Drama,Thriller}"       "{Comedy,Drama,Romance}"
      # [9] "{Documentary}"          "{Drama,Romance}"        "{Comedy,Romance}"       "{Comedy,Drama}"        
      # [13] "{Comedy}"               "{Drama}"               

#---------#1a Viz 1: Enhanced Network Graph------------
# Step 1: Convert genre_combinations into a format suitable for edge creation
edges <- lapply(genre_combinations, function(genre_combo) {
  # lapply(genre_combination: Iterates over the list of genre_combinations
  
  genres <- unlist(strsplit(genre_combo, ",", fixed = TRUE))
  # genres <- unlist: Converts the resulting list of genres into a vector.
  # strsplit(genre_combo, ",",): This function splits the comma-separated genre combo string into a list of individual genres.
  # fixed = TRUE: commas are treated as literal separators, not regular expressions.
  
  if(length(genres) > 1) {
    combn(genres, 2, simplify = FALSE)}})
  # if(length(genres) > 1): To create edges If the genre combination contains more than one genre 
  # combn(genres, 2,: Generates all possible combinations of the genres, taking them two at a time
  # simplify = FALSE): Ensures that the results are returned as a list

# Step 2: Flatten the list and remove NULLs
edges <- do.call("c", edges)
  # This flattens the nested structure of the edges list because Graph creation functions generally expect edges as a flat list of pairs.
    # Previously -> [[item1, item2], [item3, item4]], 
    # Now -> [item1, item2, item3, item4]

edges <- edges[sapply(edges, length) > 0]
  # Removes some empty pairs (e.g., []) by selecting only those elements having a length greater than 0.

# Step 3: Convert edges into a data frame
edges_df <- do.call("rbind", edges)
  # do.call: This function is a way to dynamically call another function 
  # rbind: This binds rows together, which is used to create a DataFrame-like structure.
    # 1 Action   Adventure
    # 2 Sci-Fi   Thriller

colnames(edges_df) <- c("From", "To")
  # Assigns the names "From" and "To" to the two columns of the DataFrame

# Step 4: Creating the graph from edge list
g <- graph_from_data_frame(edges_df, directed = FALSE)
  # Creates a graph object from a DataFrame 
  # directed = FALSE: Create an undirected graph edges have no directionality 
    # What it means: if 'Action' is connected to 'Adventure', then 'Adventure' is also connected to 'Action'

# Step 5: Calculate node degrees and community memberships for color-coding
node_degrees <- degree(g)
  # Calculates the degree of each node in your graph object. 
    # A higher degree implies a more "central" or well-connected genre.
    # Could look like -> Action: 3 Adventure: 2 Sci-Fi: 2 Thriller: 1

communities <- cluster_walktrap(g)
  #  Identify groups of nodes (genres) that are densely connected to each other, forming communities. 
    # Could look like -> Community 1: Action, Adventure, Sci-Fi Community 2: Thriller

# Step 6: Create a color palette based on community membership
colors <- rainbow(length(unique(membership(communities))))
  # membership(communities):Assigns a unique membership ID to each node (genre) based on its community
    # Eg: Community 1: Action, Adventure, Sci-Fi Community 2: Thriller
    # membership: [1, 1, 1, 2] -> Here, "1" is assigned to nodes in Community 1, and "2" is assigned node in Community 2.
  # unique(...): Extracts the unique community IDs. 
  # length(...): Counts the number of unique communities
  # rainbow(...):  Generates a sequence of colors forming a rainbow-like spectrum.

node_colors <- colors[membership(communities)]
  # Retrieves the community membership ID for each node again and performs the color assignment

# Step 7: Plot the enhanced graph with adjusted node sizes and colors
plot(g, layout=layout_nicely(g), 
      # layout_nicely(g): Automatically determines a suitable layout for the nodes and edges.
      # It aims for an aesthetically pleasing and uncluttered representation of g graph
     
     vertex.size=sqrt(node_degrees+1)*3, 
      # vertex.size : Controls the size of the nodes (genres) in your graph.
      # Square root: Ensures differences in sizes are noticeable.
      # Adding 1: Prevents nodes with zero connections from disappearing.
      # * 3: Multiplies the result by 3 to scale the dimensions for better visibility.

     vertex.color=node_colors, 
      # The color list created in the previous steps based on community membership
     
     vertex.label.cex=0.7,
      # Size of the node labels (genre names).
     
     main="Enhanced Network of Genre Combinations")
      # Sets the title of your graph.


#---------#1b Viz 2: Bubble Plot Graph------------
# Step 1: Get item labels and quality measures
item_labels <- labels(frequent_genres)
item_support <- quality(frequent_genres)$support
item_count <- quality(frequent_genres)$count

# Step 2: Create a dataframe for plotting
frequent_itemsets_df <- data.frame(
  labels = item_labels,
  support = item_support,
  count = item_count
)

# Step 3: Create the bubble plot
ggplot(frequent_itemsets_df, aes(x = labels, y = support, size = count)) +
  geom_point(alpha=0.6, color="red") +
  scale_size(range = c(3,12)) + # Adjust the range based on your data
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1)) +
  labs(title = "Bubble Plot of Frequent Genre Combinations", x = "Genre Combination", y = "Support", size = "Count")



#---------#2 User Similarity Matrix------------
# Step 1: Merging the ratings with the genres
ratings_with_genres <- merge(ratings, movies_genres, by = "movieId")
  # Combines two datasets (DataFrames) based on a common column.

# Step 2: Creating a user-item matrix, with users as rows and movies as columns
user_item_matrix <- dcast(ratings_with_genres, userId ~ movieId, value.var = "rating", fill = NA)
  # dcast(...) This function from the reshape2 library restructures DataFrames, pivoting data into a matrix format.
  # userId (row label) ~ movieId (column label): Defines the structure of the new matrix
  # value.var = "rating": Specifies that the rating column should be used to fill the cells in the matrix.
    

# Step 3: Create a user-genre matrix where each cell contains the average rating a user has given to all movies of that genre
user_genre_matrix <- ratings %>%
  left_join(movies_genres, by = "movieId") %>%
  group_by(userId) %>%
  mutate(genres = toString(unlist(genres_list))) %>%
  ungroup() %>%
  group_by(userId, genres) %>%
  summarise(rating_avg = mean(rating, na.rm = TRUE), .groups = 'drop') %>%
  spread(key = genres, value = rating_avg, fill = 0)
  # This code transforms your data to reveal how much users tend to enjoy movies of each genre
  # allowing the recommendation system to suggest movies based on these preferences.

# Step 4: Compute similarity matrix (example with cosine similarity)
similarity_matrix <- as.matrix(proxy::simil(x = as.matrix(user_genre_matrix[, -1]), 
                                            method = "cosine",
                                            by_rows = TRUE))

  # How similar different users are based on their movie genre preferences. 
  # Cosine similarity measures the angle between two vectors (representing users), 
    # Why: To provide a sense of how aligned their preferences are.

# Step 5: Convert similarity matrix to a more usable format if necessary
similarity_df <- as.data.frame(similarity_matrix)


#---------#2a Viz 1: Nearest Neighbor Graph------------
# Step 1: Convert the similarity matrix to an igraph graph object
# Ensure we don't include self-similarity by setting the diagonal to 0
diag(similarity_matrix) <- 0
similarity_graph <- graph_from_adjacency_matrix(similarity_matrix, mode = "undirected", weighted = TRUE)

# Step 2: Set a threshold for the similarity scores to consider for an edge 
threshold <- 0.1 
similarity_graph <- delete_edges(similarity_graph, E(similarity_graph)[weight < threshold])

#Step 3: Visualize the nearest neighbor graph 
if (!is.null(V(similarity_graph))) {
  plot(similarity_graph, vertex.size = 15, vertex.label.cex = 0.5, 
       vertex.color = "aquamarine", edge.color = "black",vertex.label.color = "black", 
       edge.width = E(similarity_graph)$weight * 10, main = "Nearest Neighbor Graph")
} else {
  message("The graph has no vertices.")
}


#---------#3 Actionable Recommendations-------

# Step 1: Identify movies with the highest average ratings across all users
target_user_id <- 51
average_movie_ratings <- aggregate(rating ~ movieId, data = ratings, FUN = mean)
highly_rated_movies <- average_movie_ratings[order(-average_movie_ratings$rating), ]

# Step 2: Find the most similar users to the given user using the similarity graph
# Extract indices of top N similar users
N <- 5 # Number of nearest neighbors
similar_users_indices <- order(similarity_matrix[target_user_id, ], decreasing = TRUE)[1:N]
similar_users <- rownames(similarity_df)[similar_users_indices]

# Step 3: Identify movies rated highly by similar users but not yet rated by the given user
# Filter ratings to only include those from similar users
ratings_from_similar_users <- ratings_with_genres[ratings_with_genres$userId %in% similar_users, ]

# Step 4: Exclude movies already rated by the target user
movies_rated_by_target_user <- ratings[ratings$userId == target_user_id, "movieId"]
unrated_movies_by_target_user <- ratings_from_similar_users[!ratings_from_similar_users$movieId %in% movies_rated_by_target_user, ]

# Step 5: Identify movies with high ratings from similar users
highly_rated_unseen_movies <- aggregate(rating ~ movieId, data = unrated_movies_by_target_user, FUN = mean)
recommendations <- merge(highly_rated_unseen_movies, movies, by = "movieId")[order(-highly_rated_unseen_movies$rating), ]

# Step 6: Print top 10 movie recommendations
top_recommendations <- recommendations[1:10, ]
print(top_recommendations)

