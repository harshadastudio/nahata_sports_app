const { Blog, User } = require('../models');
const { Op } = require('sequelize');

class BlogService {
  // Helper function to generate slug from title
  generateSlug(title) {
    return title
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-+|-+$/g, '');
  }

  // Create a new blog
  async createBlog(blogData) {
    try {
      const {
        title,
        content,
        excerpt,
        category,
        tags,
        featuredImage,
        authorId,
        status,
        publishedAt,
        metaTitle,
        metaDescription,
        metaKeywords
      } = blogData;

      console.log('📥 Blog Service - Creating blog with data:', {
        title,
        category,
        status,
        hasContent: !!content,
        hasExcerpt: !!excerpt,
        authorId: authorId || 1
      });

      // Generate slug from title
      let slug = this.generateSlug(title);
      
      // Check if slug already exists and make it unique
      const existingBlog = await Blog.findOne({ where: { slug } });
      if (existingBlog) {
        slug = `${slug}-${Date.now()}`;
      }

      // If status is published and no publishedAt date, set it to now
      const finalPublishedAt = status === 'published' && !publishedAt 
        ? new Date() 
        : publishedAt;

      // Generate excerpt if not provided
      const finalExcerpt = excerpt || (content && content.length > 200 ? content.substring(0, 200) + '...' : content);

      const blogCreateData = {
        title,
        slug,
        content,
        excerpt: finalExcerpt,
        category,
        tags: tags || [],
        authorId: authorId || 1, // Default to admin user
        status: status || 'draft',
        publishedAt: finalPublishedAt,
        metaTitle: metaTitle || title,
        metaDescription: metaDescription || excerpt,
      };

      // Only add featuredImage if it exists
      if (featuredImage) {
        blogCreateData.featuredImage = featuredImage;
      }

      // Only add metaKeywords if it exists
      if (metaKeywords) {
        blogCreateData.metaKeywords = metaKeywords;
      }

      console.log('📤 Blog Service - Attempting to create with:', Object.keys(blogCreateData));

      const blog = await Blog.create(blogCreateData);

      console.log('✅ Blog Service - Blog created successfully with ID:', blog.id);

      return blog;
    } catch (error) {
      console.error('❌ Blog Service - Error:', error.message);
      console.error('❌ Blog Service - Stack:', error.stack);
      throw new Error(`Failed to create blog: ${error.message}`);
    }
  }

  // Get all blogs with optional filters
  async getAllBlogs(filters = {}) {
    try {
      const { 
        status, 
        category, 
        authorId, 
        search,
        page = 1, 
        limit = 10 
      } = filters;
      
      const whereClause = {};
      
      if (status) whereClause.status = status;
      if (category) whereClause.category = category;
      if (authorId) whereClause.authorId = authorId;
      
      // Search in title, content, or excerpt
      if (search) {
        whereClause[Op.or] = [
          { title: { [Op.iLike]: `%${search}%` } },
          { content: { [Op.iLike]: `%${search}%` } },
          { excerpt: { [Op.iLike]: `%${search}%` } }
        ];
      }

      const offset = (page - 1) * limit;

      const { count, rows } = await Blog.findAndCountAll({
        where: whereClause,
        include: [
          {
            model: User,
            as: 'author',
            attributes: ['id', 'name', 'email'],
            required: false,
          }
        ],
        limit: parseInt(limit),
        offset: parseInt(offset),
        order: [['createdAt', 'DESC']]
      });

      return {
        blogs: rows,
        totalCount: count,
        currentPage: parseInt(page),
        totalPages: Math.ceil(count / limit)
      };
    } catch (error) {
      throw new Error(`Failed to fetch blogs: ${error.message}`);
    }
  }

  // Get blog by ID
  async getBlogById(id) {
    try {
      const blog = await Blog.findByPk(id, {
        include: [
          {
            model: User,
            as: 'author',
            attributes: ['id', 'name', 'email'],
            required: false,
          }
        ]
      });

      if (!blog) {
        throw new Error('Blog not found');
      }

      return blog;
    } catch (error) {
      throw new Error(`Failed to fetch blog: ${error.message}`);
    }
  }

  // Get blog by slug
  async getBlogBySlug(slug) {
    try {
      const blog = await Blog.findOne({
        where: { slug },
        include: [
          {
            model: User,
            as: 'author',
            attributes: ['id', 'name', 'email'],
            required: false,
          }
        ]
      });

      if (!blog) {
        throw new Error('Blog not found');
      }

      // Increment views
      await blog.increment('views');

      return blog;
    } catch (error) {
      throw new Error(`Failed to fetch blog: ${error.message}`);
    }
  }

  // Update blog
  async updateBlog(id, updateData) {
    try {
      const blog = await Blog.findByPk(id);

      if (!blog) {
        throw new Error('Blog not found');
      }

      // If title is being updated, regenerate slug
      if (updateData.title && updateData.title !== blog.title) {
        let newSlug = this.generateSlug(updateData.title);
        
        // Check if new slug already exists
        const existingBlog = await Blog.findOne({ 
          where: { 
            slug: newSlug,
            id: { [Op.ne]: id }
          } 
        });
        
        if (existingBlog) {
          newSlug = `${newSlug}-${Date.now()}`;
        }
        
        updateData.slug = newSlug;
      }

      // If status is being changed to published and no publishedAt date, set it to now
      if (updateData.status === 'published' && !blog.publishedAt && !updateData.publishedAt) {
        updateData.publishedAt = new Date();
      }

      await blog.update(updateData);

      return blog;
    } catch (error) {
      throw new Error(`Failed to update blog: ${error.message}`);
    }
  }

  // Update blog status
  async updateBlogStatus(id, status) {
    try {
      const validStatuses = ['draft', 'published', 'archived'];
      
      if (!validStatuses.includes(status)) {
        throw new Error('Invalid status');
      }

      const blog = await Blog.findByPk(id);

      if (!blog) {
        throw new Error('Blog not found');
      }

      const updateData = { status };
      
      // If publishing for the first time, set publishedAt
      if (status === 'published' && !blog.publishedAt) {
        updateData.publishedAt = new Date();
      }

      await blog.update(updateData);

      return blog;
    } catch (error) {
      throw new Error(`Failed to update blog status: ${error.message}`);
    }
  }

  // Soft delete blog
  async deleteBlog(id) {
    try {
      const blog = await Blog.findByPk(id);

      if (!blog) {
        throw new Error('Blog not found');
      }

      await blog.destroy({ force: true }); // Hard delete (permanent)

      return { message: 'Blog deleted successfully' };
    } catch (error) {
      throw new Error(`Failed to delete blog: ${error.message}`);
    }
  }

  // Increment blog views
  async incrementViews(id) {
    try {
      const blog = await Blog.findByPk(id);

      if (!blog) {
        throw new Error('Blog not found');
      }

      await blog.increment('views');

      return blog;
    } catch (error) {
      throw new Error(`Failed to increment views: ${error.message}`);
    }
  }

  // Increment blog likes
  async incrementLikes(id) {
    try {
      const blog = await Blog.findByPk(id);

      if (!blog) {
        throw new Error('Blog not found');
      }

      await blog.increment('likes');

      return blog;
    } catch (error) {
      throw new Error(`Failed to increment likes: ${error.message}`);
    }
  }

  // Get blog statistics
  async getBlogStats() {
    try {
      const { fn, col } = require('sequelize');
      
      const totalBlogs = await Blog.count();
      const publishedBlogs = await Blog.count({ where: { status: 'published' } });
      const draftBlogs = await Blog.count({ where: { status: 'draft' } });
      const archivedBlogs = await Blog.count({ where: { status: 'archived' } });

      // Total views across all blogs
      const viewsResult = await Blog.findOne({
        attributes: [[fn('SUM', col('views')), 'totalViews']],
        raw: true
      });
      const totalViews = parseInt(viewsResult?.totalViews || 0);

      // Total likes across all blogs
      const likesResult = await Blog.findOne({
        attributes: [[fn('SUM', col('likes')), 'totalLikes']],
        raw: true
      });
      const totalLikes = parseInt(likesResult?.totalLikes || 0);

      // Get categories with blog counts
      const categoriesResult = await Blog.findAll({
        attributes: [
          'category',
          [fn('COUNT', col('id')), 'count']
        ],
        group: ['category'],
        raw: true
      });

      return {
        total: totalBlogs,
        published: publishedBlogs,
        draft: draftBlogs,
        archived: archivedBlogs,
        totalViews,
        totalLikes,
        categories: categoriesResult
      };
    } catch (error) {
      throw new Error(`Failed to fetch blog statistics: ${error.message}`);
    }
  }

  // Get popular blogs (by views)
  async getPopularBlogs(limit = 5) {
    try {
      const blogs = await Blog.findAll({
        where: { status: 'published' },
        include: [
          {
            model: User,
            as: 'author',
            attributes: ['id', 'name', 'email'],
            required: false,
          }
        ],
        order: [['views', 'DESC']],
        limit: parseInt(limit)
      });

      return blogs;
    } catch (error) {
      throw new Error(`Failed to fetch popular blogs: ${error.message}`);
    }
  }

  // Get recent blogs
  async getRecentBlogs(limit = 5) {
    try {
      const blogs = await Blog.findAll({
        where: { status: 'published' },
        include: [
          {
            model: User,
            as: 'author',
            attributes: ['id', 'name', 'email'],
            required: false,
          }
        ],
        order: [['publishedAt', 'DESC']],
        limit: parseInt(limit)
      });

      return blogs;
    } catch (error) {
      throw new Error(`Failed to fetch recent blogs: ${error.message}`);
    }
  }

  // Get unique categories from blogs
  async getUniqueCategories() {
    try {
      const { fn, col } = require('sequelize');
      
      const categories = await Blog.findAll({
        attributes: [
          [fn('DISTINCT', col('category')), 'name']
        ],
        where: {
          category: {
            [Op.ne]: null,
            [Op.ne]: ''
          }
        },
        order: [[col('category'), 'ASC']],
        raw: true
      });

      // Transform to include id and srNo
      return categories.map((cat, index) => ({
        id: index + 1,
        srNo: index + 1,
        name: cat.name
      }));
    } catch (error) {
      throw new Error(`Failed to fetch categories: ${error.message}`);
    }
  }

  // Check if category exists
  async categoryExists(categoryName) {
    try {
      const blog = await Blog.findOne({
        where: {
          category: categoryName
        }
      });
      return !!blog;
    } catch (error) {
      throw new Error(`Failed to check category: ${error.message}`);
    }
  }

  // Create a new category (by creating a placeholder blog or just validating)
  async createCategory(categoryName) {
    try {
      // Check if category already exists
      const exists = await this.categoryExists(categoryName);
      
      if (exists) {
        throw new Error('Category already exists');
      }

      // Get current categories to determine the next ID
      const categories = await this.getUniqueCategories();
      const nextId = categories.length + 1;

      // Return the new category object
      // Note: The category will only appear in the list after a blog uses it
      // For immediate display, we return it here and the frontend adds it to the state
      return {
        id: nextId,
        srNo: nextId,
        name: categoryName,
        message: 'Category created successfully. It will be available for use in blogs.'
      };
    } catch (error) {
      throw new Error(`Failed to create category: ${error.message}`);
    }
  }

  // Update category name (updates all blogs with old category to new category)
  async updateCategory(oldName, newName) {
    try {
      // Check if new name already exists
      const exists = await this.categoryExists(newName);
      
      if (exists && oldName !== newName) {
        throw new Error('New category name already exists');
      }

      // Update all blogs with the old category name
      const [updatedCount] = await Blog.update(
        { category: newName },
        {
          where: {
            category: oldName
          }
        }
      );

      return {
        message: `Updated ${updatedCount} blog(s) with new category name`,
        updatedCount
      };
    } catch (error) {
      throw new Error(`Failed to update category: ${error.message}`);
    }
  }

  // Delete category (removes category from all blogs or sets to 'Uncategorized')
  async deleteCategory(categoryName) {
    try {
      // Update all blogs with this category to 'Uncategorized'
      const [updatedCount] = await Blog.update(
        { category: 'Uncategorized' },
        {
          where: {
            category: categoryName
          }
        }
      );

      return {
        message: `Moved ${updatedCount} blog(s) to 'Uncategorized'`,
        updatedCount
      };
    } catch (error) {
      throw new Error(`Failed to delete category: ${error.message}`);
    }
  }
}

module.exports = new BlogService();
