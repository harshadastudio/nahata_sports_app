const blogService = require('../services/blogService');

class BlogController {
  // Create a new blog
  async createBlog(req, res) {
    try {
      const blogData = req.body;

      console.log('📥 Received blog data:', JSON.stringify(blogData, null, 2));

      // Validate required fields
      const requiredFields = ['title', 'content', 'category'];
      const missingFields = requiredFields.filter(field => !blogData[field] || (typeof blogData[field] === 'string' && !blogData[field].trim()));

      if (missingFields.length > 0) {
        console.log('❌ Missing fields:', missingFields);
        return res.status(400).json({
          success: false,
          message: `Missing required fields: ${missingFields.join(', ')}`
        });
      }

      const blog = await blogService.createBlog(blogData);

      console.log('✅ Blog created successfully:', blog.id);

      res.status(201).json({
        success: true,
        message: 'Blog created successfully',
        data: blog
      });
    } catch (error) {
      console.error('❌ Blog creation error:', error.message);
      res.status(400).json({
        success: false,
        message: error.message
      });
    }
  }

  // Get all blogs with filters
  async getAllBlogs(req, res) {
    try {
      const filters = {
        status: req.query.status,
        category: req.query.category,
        authorId: req.query.authorId,
        search: req.query.search,
        page: req.query.page || 1,
        limit: req.query.limit || 10
      };

      const result = await blogService.getAllBlogs(filters);

      res.status(200).json({
        success: true,
        data: result.blogs,
        pagination: {
          currentPage: result.currentPage,
          totalPages: result.totalPages,
          totalCount: result.totalCount,
          limit: parseInt(filters.limit)
        }
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        message: error.message
      });
    }
  }

  // Get blog by ID
  async getBlogById(req, res) {
    try {
      const { id } = req.params;

      if (!id) {
        return res.status(400).json({
          success: false,
          message: 'Blog ID is required'
        });
      }

      const blog = await blogService.getBlogById(id);

      res.status(200).json({
        success: true,
        data: blog
      });
    } catch (error) {
      res.status(404).json({
        success: false,
        message: error.message
      });
    }
  }

  // Get blog by slug
  async getBlogBySlug(req, res) {
    try {
      const { slug } = req.params;

      if (!slug) {
        return res.status(400).json({
          success: false,
          message: 'Blog slug is required'
        });
      }

      const blog = await blogService.getBlogBySlug(slug);

      res.status(200).json({
        success: true,
        data: blog
      });
    } catch (error) {
      res.status(404).json({
        success: false,
        message: error.message
      });
    }
  }

  // Update blog
  async updateBlog(req, res) {
    try {
      const { id } = req.params;
      const updateData = req.body;

      if (!id) {
        return res.status(400).json({
          success: false,
          message: 'Blog ID is required'
        });
      }

      const blog = await blogService.updateBlog(id, updateData);

      res.status(200).json({
        success: true,
        message: 'Blog updated successfully',
        data: blog
      });
    } catch (error) {
      res.status(400).json({
        success: false,
        message: error.message
      });
    }
  }

  // Update blog status
  async updateBlogStatus(req, res) {
    try {
      const { id } = req.params;
      const { status } = req.body;

      if (!id || !status) {
        return res.status(400).json({
          success: false,
          message: 'Blog ID and status are required'
        });
      }

      const blog = await blogService.updateBlogStatus(id, status);

      res.status(200).json({
        success: true,
        message: 'Blog status updated successfully',
        data: blog
      });
    } catch (error) {
      res.status(400).json({
        success: false,
        message: error.message
      });
    }
  }

  // Delete blog (soft delete)
  async deleteBlog(req, res) {
    try {
      const { id } = req.params;

      if (!id) {
        return res.status(400).json({
          success: false,
          message: 'Blog ID is required'
        });
      }

      const result = await blogService.deleteBlog(id);

      res.status(200).json({
        success: true,
        message: result.message
      });
    } catch (error) {
      res.status(400).json({
        success: false,
        message: error.message
      });
    }
  }

  // Increment blog views
  async incrementViews(req, res) {
    try {
      const { id } = req.params;

      if (!id) {
        return res.status(400).json({
          success: false,
          message: 'Blog ID is required'
        });
      }

      const blog = await blogService.incrementViews(id);

      res.status(200).json({
        success: true,
        message: 'Views incremented successfully',
        data: blog
      });
    } catch (error) {
      res.status(400).json({
        success: false,
        message: error.message
      });
    }
  }

  // Increment blog likes
  async incrementLikes(req, res) {
    try {
      const { id } = req.params;

      if (!id) {
        return res.status(400).json({
          success: false,
          message: 'Blog ID is required'
        });
      }

      const blog = await blogService.incrementLikes(id);

      res.status(200).json({
        success: true,
        message: 'Likes incremented successfully',
        data: blog
      });
    } catch (error) {
      res.status(400).json({
        success: false,
        message: error.message
      });
    }
  }

  // Get blog statistics
  async getBlogStats(req, res) {
    try {
      const stats = await blogService.getBlogStats();

      res.status(200).json({
        success: true,
        data: stats
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        message: error.message
      });
    }
  }

  // Get popular blogs
  async getPopularBlogs(req, res) {
    try {
      const limit = req.query.limit || 5;
      const blogs = await blogService.getPopularBlogs(limit);

      res.status(200).json({
        success: true,
        data: blogs
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        message: error.message
      });
    }
  }

  // Get recent blogs
  async getRecentBlogs(req, res) {
    try {
      const limit = req.query.limit || 5;
      const blogs = await blogService.getRecentBlogs(limit);

      res.status(200).json({
        success: true,
        data: blogs
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        message: error.message
      });
    }
  }

  // Get unique categories
  async getCategories(req, res) {
    try {
      const categories = await blogService.getUniqueCategories();

      res.status(200).json({
        success: true,
        data: categories
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        message: error.message
      });
    }
  }

  // Create a new category
  async createCategory(req, res) {
    try {
      const { name } = req.body;

      if (!name || !name.trim()) {
        return res.status(400).json({
          success: false,
          message: 'Category name is required'
        });
      }

      const category = await blogService.createCategory(name.trim());

      res.status(201).json({
        success: true,
        message: 'Category created successfully',
        data: category
      });
    } catch (error) {
      res.status(400).json({
        success: false,
        message: error.message
      });
    }
  }

  // Update category
  async updateCategory(req, res) {
    try {
      const { oldName } = req.params;
      const { newName } = req.body;

      if (!newName || !newName.trim()) {
        return res.status(400).json({
          success: false,
          message: 'New category name is required'
        });
      }

      const result = await blogService.updateCategory(oldName, newName.trim());

      res.status(200).json({
        success: true,
        message: result.message,
        data: result
      });
    } catch (error) {
      res.status(400).json({
        success: false,
        message: error.message
      });
    }
  }

  // Delete category
  async deleteCategory(req, res) {
    try {
      const { name } = req.params;

      if (!name) {
        return res.status(400).json({
          success: false,
          message: 'Category name is required'
        });
      }

      const result = await blogService.deleteCategory(name);

      res.status(200).json({
        success: true,
        message: result.message,
        data: result
      });
    } catch (error) {
      res.status(400).json({
        success: false,
        message: error.message
      });
    }
  }
}

module.exports = new BlogController();
